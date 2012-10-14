prelude.installPrelude window

PI2 = Math.PI*2
ZERO2 = [0, 0]

SETTINGS =
  player:
    name: null
  server: "192.168.1.37:8080"
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
map ((x) -> if x is not null and typeof x is "object" then x.value = x.base; x), SETTINGS

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

# Read field value and replace it with actual Vector
to-vector = (object, field) -> object[field] = Vector.create object[field].elements

msg-id-is = (value, object) -> object[\id] == value

log = (msg) -> console.log msg

$ ->
  ST =
    ships: [
      player: SETTINGS.player
      velocity: Vector.create ZERO2
      heading: Vector.create [0, -1]
      position: SETTINGS.window-dimensions.multiply 0.5
      shots: []
      shot-tick: 0
    ]
    asteroids: [
      position: SETTINGS.window-dimensions.multiply 0.2
      velocity: Vector.create([0.1, 0]).rotate Math.random!, ZERO2
      diameter: 100.0
      removed: false
    ]
    tick: 0
    input: []

  flush = (objects) ->
    objects.filter ((o) -> o.removed == false)

  insideRectagle = (rect, v) ->
    v.elements[0] < 0 \
      or v.elements[1] < 0 \
      or v.elements[0] > rect.elements[0] \
      or v.elements[1] > rect.elements[1]

  splitAsteroid = (state, asteroid) ->
    asteroid.diameter /= 2
    asteroid.velocity = asteroid.velocity.multiply 2 .rotate Math.random!*PI2, ZERO2
    state.asteroids.push {
      position: asteroid.position.dup!
      velocity: asteroid.velocity.dup!.rotate Math.random!*PI2, ZERO2
      diameter: asteroid.diameter
      removed: false
    }

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
            c.arc 0, 0, SETTINGS.ship-size.value, 0, PI2
          path c, ->
            c.moveTo 0, 0
            c.lineTo ship.heading.elements[0] * 50, ship.heading.elements[1] * 50

        c.fillStyle = \#C0C
        c.fillText ship.player.name,
                   ship.position.elements[0],
                   ship.position.elements[1]

      c.strokeStyle = \#00F
      for asteroid in state.asteroids
        batch c, ->
          c.translate asteroid.position.elements[0], asteroid.position.elements[1]
          path c, ->
            c.arc 0, 0, asteroid.diameter, 0, PI2

  tick = (state) ->
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

    for asteroid in state.asteroids
      asteroid.position = asteroid.position.add(asteroid.velocity)
      if insideRectagle SETTINGS.window-dimensions, asteroid.position
        asteroid.removed = true
    state.asteroids = state.asteroids |> flush

    for ship in state.ships
      ship.position = ship.position.add(ship.velocity)
      for shot in ship.shots when shot.removed is false
        shot.position = shot.position.add(shot.dir)
        diff = SETTINGS.window-dimensions.subtract(shot.position)
        if insideRectagle SETTINGS.window-dimensions, shot.position
          shot.removed = true
        for asteroid in state.asteroids when asteroid.removed is false
          if shot.position.distanceFrom(asteroid.position) < asteroid.diameter
            shot.removed = true
            splitAsteroid state, asteroid
      ship.shots = ship.shots |> flush

  bind = ->
    concat = (a1, a2) -> a1.concat a2
    ups = $ document .asEventStream \keyup
    downs = $ document .asEventStream \keydown
    always = (value) -> ((_) -> value)
    select = (key, stream) -> (stream.filter ((event) -> event.keyCode == key.code))
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
    send-state = (ws, state) ->
      data =
        action: "update"
        data: state
      ws.send data

    deserialize-state = (msg) ->
      to-vector msg.data, \velocity
      to-vector msg.data, \heading
      to-vector msg.data, \position
      msg.data.id = msg.from
      msg.data.shots = map ((e) ->
        to-vector e, \position
        to-vector e, \dir
        e), msg.data.shots
      msg

    connection = (url) ->
      emit = (ctx, event, data) ->
        $ ctx .trigger(jQuery.Event event, {_data: data})
      data-stream = (ctx, trigger-name) ->
        $ ctx .asEventStream trigger-name .map (e) -> e._data.data
      _ws = new WebSocket url
      _ws.onopen    = (e) -> emit _ws, "ws-open", e
      _ws.onclose   = (e) -> emit _ws, "ws-close", e
      _ws.onerror   = (e) -> emit _ws, "ws-error", e
      _ws.onmessage = (e) -> emit _ws, "click", e
      {
        onopen:    -> data-stream _ws, \ws-open
        onclose:   -> data-stream _ws, \ws-close
        onerror:   -> data-stream _ws, \ws-error
        onmessage: -> data-stream _ws, \click
        send: (obj) -> _ws.send JSON.stringify obj
      }

    ws = connection 'ws://'+SETTINGS.server+'/game'
    ws.onopen!.onValue (e) -> setInterval (-> send-state ws, ST.ships[0]), SETTINGS.state-throttle
    ws.onerror!.onValue log

    ws-connected = ws.onopen!.map true
    ws-disconnected = ws.onclose!.map false
    ws-connected.merge ws-disconnected
                .onValue (is-connected) -> $ \.connected .toggle is-connected
                                           $ \.disconnected .toggle !is-connected

    # Flush everyone else on disconnect
    ws-disconnected.onValue !-> ST.ships = take 1, ST.ships

    all-messages = ws.onmessage!.map JSON.parse
    state-messages = all-messages .filter msg-id-is, \STATE
    leave-messages = all-messages .filter msg-id-is, \LEAVE

    # Create or update another player
    state-messages .map deserialize-state .onValue (msg) ->
      ship = find ((e) -> e.id != undefined and e.id == msg.from), ST.ships
      if ship is undefined
        ST.ships.push msg.data
      else
        ship <<< msg.data

    # Remove leaving player
    leave-messages.onValue (msg) ->
      ST.ships = reject ((s) -> s.id == msg.from), ST.ships

  setInterval (-> tick ST; ST.tick++), 10
  setInterval makeRenderer(ST), 16 # 1000/60 -> ~60 fps
  bind!.onValue (keys-down) -> ST.input := keys-down
  network!

export SETTINGS
