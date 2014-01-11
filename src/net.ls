define ['util', 'state', 'settings'], (util, st, settings) ->
  strip-decimals = (numbers, max-decimals) ->
    tmp = (10^max-decimals)
    map (-> Math.round(it * tmp) / tmp), numbers

  serialize = (ship) ->
    name: ship.player.name
    shots: map (->
      distance: it.distance
      max-distance: settings.shot-range.value
      position: strip-decimals it.position.toArray!, 1
      dir: strip-decimals it.dir.toArray!, 5), ship.shots
    energy: ship.energy
    diameter: ship.diameter.value
    velocity: strip-decimals ship.velocity.toArray!, 5
    heading: strip-decimals ship.heading.toArray!, 5
    position: strip-decimals ship.position.toArray!, 2

  deserialize = (msg) ->
    ship = msg.data
    {
      id: msg.from
      player:
        name: ship.name
      shots: map (->
        distance: it.distance
        max-distance: it.max-distance
        position: new THREE.Vector2!.fromArray it.position
        dir: new THREE.Vector2!.fromArray it.dir
        removed: false), ship.shots
      energy: ship.energy
      diameter:
        value: ship.diameter
      velocity: new THREE.Vector2!.fromArray ship.velocity
      heading: new THREE.Vector2!.fromArray ship.heading
      position: new THREE.Vector2!.fromArray ship.position
    }

  # Wrap WebSocket events in Bacon and make send() a JSON serializer
  connection = (url) ->
    ws = new WebSocket url
    update = new Bacon.Bus!
    update.filter -> it is not void
        .map serialize
        .map (-> id: \UPDATE, channel: settings.channel, data: it)
        .map JSON.stringify
        .onValue (-> ws.send it)
    out = new Bacon.Bus!
    out.map JSON.stringify
        .onValue (-> ws.send it)
    fields = map -> [it], [\onopen \onclose \onerror \onmessage]
    field-bus-pairs = each (-> bus = new Bacon.Bus!; ws[it] = bus.push; it.push -> bus), fields
    methods = field-bus-pairs |> listToObj
    methods.update = update.push
    methods.send = (id, data, channel = settings.channel) -> out.push(id: id, channel: channel, data: data)
    methods

  ws = connection 'ws://'+settings.server+'/game'
  ws.onopen!.onValue !-> setInterval (->
    if st.input-dirty
      ws.update find (.id is void), st.ships
      st.input-dirty = false), settings.state-throttle
  ws.onerror!.onValue util.log

  ws-connected = ws.onopen!.map true
  ws-disconnected = ws.onclose!.map false
  ws-connected.merge(ws-disconnected)
              .onValue (is-connected) ->
                $ \.connected .toggle is-connected
                $ \.disconnected .toggle !is-connected

  # Flush everyone else on disconnect
  ws-disconnected.onValue !-> st.ships = take 1, st.ships

  all-messages = ws.onmessage!.map (.data)
                              .do (-> if settings.dump then util.log(it))
                              .map JSON.parse
                              .filter ((it) -> it.channel == 0 || it.channel == settings.channel)
  state-messages = all-messages .filter (.id == \UPDATE)
  dead-messages = all-messages .filter (.id == \DEAD)
  leave-messages = all-messages .filter (.id == \LEAVE)

  dead-messages .onValue (msg) ->
    st.ships = reject (.id == msg.from), st.ships

  # Create or update another player
  state-messages .map deserialize .onValue (ship) ->
    existing-ship = find (-> it.id != void and it.id == ship.id), st.ships
    if existing-ship is void
      st.ships.push ship
      st.input-dirty = true
    else
      existing-ship <<< ship

  # Remove leaving player
  leave-messages.onValue (msg) ->
    st.ships = reject (.id == msg.from), st.ships

  ws
