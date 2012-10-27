prelude.installPrelude window

PI2 = Math.PI*2
ZERO2 = [0, 0]

SETTINGS =
  dump: false
  max-energy: 10
  max-velocity: 1.5
  player:
    name: null
  server: ENV.serverAddress
  framerate: 60
  tickrate: 100
  state-throttle: 100
  window-dimensions: Vector.create [800, 600]
  acceleration:
    value: null
    base: 0.04
    step: 0.01
  turn:
    value: null
    base: 0.04
    step: 0.01
  shot-velocity:
    value: null
    base: 4.0
    step: 0.5
  shot-delay:
    value: null
    base: 10
    step: -3
  ship-size:
    value: null
    base: 15
    step: -4

# Set base as default value
map (-> if it is not null and typeof it is "object" then it.value = it.base; it), SETTINGS

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

log = !(msg) -> console.log msg

strip-decimals = (numbers, max-decimals) ->
  tmp = (10^max-decimals)
  map (-> Math.round(it * tmp) / tmp), numbers

$ ->
  ST =
    ships: [
      player: SETTINGS.player
      velocity: Vector.create ZERO2
      heading: Vector.create [0, -1]
      position: SETTINGS.window-dimensions.multiply 0.5
      shots: []
      shot-tick: 0
      diameter: SETTINGS.ship-size
      energy: SETTINGS.max-energy
      deaths: 0
    ]
    tick: 0
    input: []
    input-dirty: true

  flush = (.filter (.removed == false))

  insideRectagle = (rect, v) ->
    v.elements[0] < 0 \
      or v.elements[1] < 0 \
      or v.elements[0] > rect.elements[0] \
      or v.elements[1] > rect.elements[1]

  makeRenderer = (state) ->
    batch = (ctx, closure) ->
      ctx.save!
      closure ctx
      ctx.restore!

    path = (ctx, closure) ->
      ctx.beginPath!
      closure ctx
      ctx.stroke!

    canvas =  $ "<canvas>" .appendTo $ \#viewport
    canvas.attr \width SETTINGS.window-dimensions.elements[0]
    canvas.attr \height SETTINGS.window-dimensions.elements[1]
    c = canvas[0].getContext \2d
    c.lineCap = \round
    c.lineWidth = 0

    ->
      c.clearRect 0, 0, c.canvas.width, c.canvas.height
      c.strokeStyle = \#F00

      for ship in state.ships
        for shot in ship.shots when shot.removed is false
          batch c, ->
            c.translate shot.position.elements[0], shot.position.elements[1]
            path c, ->
              c.arc 0, 0, 4, 0, PI2

        batch c, ->
          c.strokeStyle = \#000
          c.translate ship.position.elements[0], ship.position.elements[1]
          path c, ->
            c.arc 0, 0, ship.diameter.value, 0, PI2
          path c, ->
            c.moveTo 0, 0
            c.lineTo ship.heading.elements[0] * 50, ship.heading.elements[1] * 50

        c.fillStyle = \#C0C
        c.fillText ship.player.name,
                   ship.position.elements[0],
                   ship.position.elements[1]
        c.fillStyle = \#0C0
        c.strokeRect ship.position.elements[0]-30,
                   ship.position.elements[1]-50, 60, 4
        c.fillRect ship.position.elements[0]-30,
                   ship.position.elements[1]-50, (ship.energy/SETTINGS.max-energy*60), 4
        c.fillStyle = \#F00
        c.fillText ship.deaths,
                   ship.position.elements[0]-30,
                   ship.position.elements[1]+50

  tick = (connection, state) ->
    player = state.ships[0]
    velocity-change = player.heading.multiply SETTINGS.acceleration.value

    for key in state.input
      switch key.code
      | KEY.up.code    => player.velocity = player.velocity.add velocity-change
      | KEY.down.code  => player.velocity = player.velocity.subtract velocity-change
      | KEY.left.code  => player.heading = player.heading.rotate -SETTINGS.turn.value, ZERO2
      | KEY.right.code => player.heading = player.heading.rotate SETTINGS.turn.value, ZERO2
      | KEY.space.code => \
        if state.tick - player.shot-tick > SETTINGS.shot-delay.value
          player.shot-tick = state.tick
          player.shots.push {
            position: player.position.dup!
            dir: player.heading.toUnitVector!.multiply(SETTINGS.shot-velocity.value)
            removed: false
          }

    if state.input.length > 0
      ST.input-dirty = true
      if player.velocity.distanceFrom(ZERO2) > SETTINGS.max-velocity
        player.velocity = player.velocity.toUnitVector!.multiply SETTINGS.max-velocity

    for ship in state.ships
      if ship.energy <= 0
        ship.energy = SETTINGS.max-energy
        ship.deaths++
      ship.position = ship.position.add(ship.velocity)
      for shot in ship.shots when shot.removed is false
        shot.position = shot.position.add(shot.dir)
        diff = SETTINGS.window-dimensions.subtract(shot.position)
        if insideRectagle SETTINGS.window-dimensions, shot.position
          shot.removed = true
        for enemy in state.ships
          if enemy.id == ship.id
            continue
          if shot.position.distanceFrom(enemy.position) < enemy.diameter.value
            shot.removed = true
            enemy.energy--
            if enemy.id is undefined and enemy.energy <= 0
              connection.send(\DEAD, by: ship.id)
      ship.shots = ship.shots |> flush

  bind = ->
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

  network = ->
    serialize = (ship) ->
      {
        name: ship.player.name
        shots: map (->
          {
            position: strip-decimals it.position.elements, 1
            dir: strip-decimals it.dir.elements, 5
          }), ship.shots
        energy: ship.energy
        deaths: ship.deaths
        diameter: ship.diameter.value
        velocity: strip-decimals ship.velocity.elements, 1
        heading: strip-decimals ship.heading.elements, 3
        position: strip-decimals ship.position.elements, 1
      }

    deserialize = (msg) ->
      ship = msg.data
      {
        id: msg.from
        player: { name: ship.name }
        shots: map (->
          {
            position: Vector.create it.position
            dir: Vector.create it.dir
            removed: false
          }), ship.shots
        energy: ship.energy
        deaths: ship.deaths
        diameter: { value: ship.diameter }
        velocity: Vector.create ship.velocity
        heading: Vector.create ship.heading
        position: Vector.create ship.position
      }

    # Wrap WebSocket events in Bacon and make send() a JSON serializer
    connection = (url) ->
      ws = new WebSocket url
      update = new Bacon.Bus!
      update.map serialize
         .map (-> { id: \UPDATE, data: it })
         .map JSON.stringify
         .onValue (-> ws.send it)
      out = new Bacon.Bus!
      out.map JSON.stringify
         .onValue (-> ws.send it)
      fields = map -> [it], [\onopen \onclose \onerror \onmessage]
      field-bus-pairs = each (-> bus = new Bacon.Bus!; ws[it] = bus.push; it.push -> bus), fields
      methods = field-bus-pairs |> listToObj
      methods.update = update.push
      methods.send = (id, data) -> out.push { id: id, data: data }
      methods

    ws = connection 'ws://'+SETTINGS.server+'/game'
    ws.onopen!.onValue !-> setInterval (->
      if ST.input-dirty
        ws.update ST.ships[0]
        ST.input-dirty = false), SETTINGS.state-throttle
    ws.onerror!.onValue log

    ws-connected = ws.onopen!.map true
    ws-disconnected = ws.onclose!.map false
    ws-connected.merge ws-disconnected
                .onValue (is-connected) -> $ \.connected .toggle is-connected
                                           $ \.disconnected .toggle !is-connected

    # Flush everyone else on disconnect
    ws-disconnected.onValue !-> ST.ships = take 1, ST.ships

    all-messages = ws.onmessage!.map (.data)
                                .do (-> if SETTINGS.dump then log(it))
                                .map JSON.parse
    state-messages = all-messages .filter (.id == \UPDATE)
    leave-messages = all-messages .filter (.id == \LEAVE)

    # Create or update another player
    state-messages .map deserialize .onValue (ship) ->
      existing-ship = find (-> it.id != undefined and it.id == ship.id), ST.ships
      if existing-ship is undefined
        ST.ships.push ship
        ST.input-dirty = true
      else
        existing-ship <<< ship

    # Remove leaving player
    leave-messages.onValue (msg) ->
      ST.ships = reject (.id == msg.from), ST.ships

    ws

  connection = network!
  setInterval (-> tick connection, ST; ST.tick++), 1000 / SETTINGS.tickrate
  setInterval makeRenderer(ST), 1000 / SETTINGS.framerate
  bind!.onValue (keys-down) -> ST.input := keys-down

export SETTINGS
