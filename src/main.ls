prelude.installPrelude window

KEY =
  up:
    code: 38
  space:
    code: 32
  down:
    code: 40
  left:
    code: 37
  right:
    code: 39
  esc:
    code: 27

log = !(msg) -> console.log msg

strip-decimals = (numbers, max-decimals) ->
  tmp = (10^max-decimals)
  map (-> Math.round(it * tmp) / tmp), numbers

# Wrap value to range [0..limit]
value-wrap = ->
  [value, limit] = it
  if value < 0
    value += limit
  value %= limit
  value

# Wrap vector into given bounding box of equal dimensions
vector-wrap = (bounding-box, vector) -->
  new THREE.Vector2!.fromArray map value-wrap, zip(vector.toArray!, bounding-box.toArray!)

requirejs.config {baseUrl: '.'}

requirejs ['state', 'util', 'ui', 'draw', 'settings'], (st, util, ui, draw, settings)->
  flush = (.filter (.removed == false))

  adjust-canvas-size = ! ->
    $ "canvas"
      ..attr \width window.innerWidth
      ..attr \height window.innerHeight

  time-scale = (delta-ms) ->
    (per-second) ->
      per-second * (delta-ms / 1000)

  out-of-bounding-box = (rect, v) ->
    v.x < 0 or v.y < 0 or v.x > rect.x  or v.y > rect.y

  world-wrap = (position) ->
    if out-of-bounding-box settings.window-dimensions, position
      vector-wrap(settings.window-dimensions)(position)
    else
      position

  rotate-vector2 = !(vector2, radians) ->
    m = new THREE.Matrix4!.makeRotationZ radians
    tmp = new THREE.Vector3 vector2.x, vector2.y, 0
    tmp.applyMatrix4 m
    vector2.set tmp.x, tmp.y

  delta-timer = ->
    start = new Date!.getTime!
    prev = start
    ->
      now = new Date!.getTime!
      delta = now - prev
      prev := now
      delta

  tick = (connection, state, delta, renderer) ->
    adjust = time-scale delta
    player = state.ships[0]

    for entry in st.queue
      connection.send(entry.id, entry.data, 0)
    st.queue = []

    if player and player.id is void
      velocity-change = player.heading.clone!.multiplyScalar adjust(settings.acceleration.value)
      for key in state.input
        switch key.code
        | KEY.esc.code   =>
          if player.energy > 0
            player.energy = 0
            connection.send(\DEAD, by: player.id)
            $('input[name=spawn]').removeAttr \disabled
            $ \#setup .removeClass \hidden
        | KEY.up.code    => player.velocity.add velocity-change
        | KEY.down.code  => player.velocity.sub velocity-change
        | KEY.left.code  => rotate-vector2 player.heading, adjust(-settings.turn.value)
        | KEY.right.code => rotate-vector2 player.heading, adjust(settings.turn.value)
        | KEY.space.code => \
          if state.tick - player.shot-tick > settings.shot-delay.value
            player.shot-tick = state.tick
            player.shots.push {
              position: player.position.clone!
              distance: 0
              max-distance: settings.shot-range.value
              dir: player.heading.clone!.normalize!.multiplyScalar(settings.shot-velocity.value)
              removed: false
            }

      if state.input.length > 0
        st.input-dirty = true
        if player.velocity.distanceTo(util.ZERO2) > settings.max-velocity
          player.velocity.normalize!.multiplyScalar settings.max-velocity

    for ship in state.ships
      ship.position = world-wrap ship.position.add(ship.velocity)
      for shot in ship.shots when shot.removed is false
        shot.distance += shot.dir.distanceTo(util.ZERO2)
        shot.position = shot.position.add(shot.dir)
        diff = settings.window-dimensions.clone!.sub(shot.position)
        if shot.distance > shot.max-distance
          shot.removed = true
          continue
        shot.position = world-wrap shot.position
        for enemy in state.ships
          if enemy.id == ship.id
            continue
          if shot.position.distanceTo(enemy.position) < enemy.diameter.value
            shot.removed = true
            enemy.energy--
            if enemy.id is void and enemy.energy <= 0
              connection.send(\DEAD, by: ship.id)
              $('input[name=spawn]').removeAttr \disabled
              $ \#setup .removeClass \hidden

      ship.shots = ship.shots |> flush

    st.ships = reject (.energy <= 0), st.ships

    window.requestAnimationFrame renderer

  bind = ->
    Bacon.fromEventTarget(window, 'resize').throttle(100).onValue adjust-canvas-size
    concat = (a1, a2) -> a1.concat a2
    ups = $ document .asEventStream \keyup
    downs = $ document .asEventStream \keydown
    always = (value) -> ((_) -> value)
    select = (key, stream) -> (stream.filter (.keyCode == key.code))
    state = (key) -> select(key, downs) \
      .map(always([key])) \
      .merge(select(key, ups).map(always([]))) \
      .toProperty([])

    state(KEY.up)
      .combine state(KEY.down), concat
      .combine state(KEY.left), concat
      .combine state(KEY.right), concat
      .combine state(KEY.space), concat
      .combine state(KEY.esc), concat

  network = ->
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
    ws.onerror!.onValue log

    ws-connected = ws.onopen!.map true
    ws-disconnected = ws.onclose!.map false
    ws-connected.merge(ws-disconnected)
                .onValue (is-connected) ->
                  $ \.connected .toggle is-connected
                  $ \.disconnected .toggle !is-connected

    # Flush everyone else on disconnect
    ws-disconnected.onValue !-> st.ships = take 1, st.ships

    all-messages = ws.onmessage!.map (.data)
                                .do (-> if settings.dump then log(it))
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


  tick-delta = delta-timer!
  connection = network!
  setInterval (-> tick connection, st, tick-delta!, draw; st.tick++), 1000 / settings.tickrate
  bind!.onValue (keys-down) -> st.input := keys-down
