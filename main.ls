prelude.installPrelude window

PI2 = Math.PI*2
ZERO2 = [0, 0]

SETTINGS =
  dump: false
  player:
    name: null
  server: "192.168.1.37:8080"
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

log = (msg) -> console.log msg

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
      energy: 100
      deaths: 0
    ]
    asteroids: [
      position: SETTINGS.window-dimensions.multiply 0.2
      velocity: Vector.create([0.1, 0]).rotate Math.random!, ZERO2
      diameter: 100.0
      removed: false
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
                   ship.position.elements[1]-50, (ship.energy/100*60), 4
        c.fillStyle = \#F00
        c.fillText ship.deaths,
                   ship.position.elements[0]-30,
                   ship.position.elements[1]+50

      c.strokeStyle = \#00F
      for asteroid in state.asteroids
        batch c, ->
          c.translate asteroid.position.elements[0], asteroid.position.elements[1]
          path c, ->
            c.arc 0, 0, asteroid.diameter, 0, PI2

  tick = (state) ->
    player = state.ships[0]
    velocity-change = player.heading.multiply SETTINGS.acceleration.value

    if player.energy <= 0
      player.energy = 100
      player.deaths++

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
        for enemy in state.ships
          if enemy.id == ship.id
            continue
          if shot.position.distanceFrom(enemy.position) < enemy.diameter.value
            shot.removed = true
            enemy.energy--
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
      out = new Bacon.Bus!
      out.map serialize
         .map (-> { action: \update, data: it })
         .map JSON.stringify
         .skipDuplicates!
         .onValue (-> ws.send it)
      fields = map -> [it], [\onopen \onclose \onerror \onmessage]
      field-bus-pairs = each (-> bus = new Bacon.Bus!; ws[it] = bus.push; it.push -> bus), fields
      methods = field-bus-pairs |> listToObj
      methods.send = out.push
      methods

    ws = connection 'ws://'+SETTINGS.server+'/game'
    ws.onopen!.onValue !-> setInterval (->
      if ST.input-dirty
        ws.send ST.ships[0]
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
    state-messages = all-messages .filter (.id == \STATE)
    leave-messages = all-messages .filter (.id == \LEAVE)

    # Create or update another player
    state-messages .map deserialize .onValue (ship) ->
      existing-ship = find (-> it.id != undefined and it.id == ship.id), ST.ships
      if existing-ship is undefined
        ST.ships.push ship
      else
        existing-ship <<< ship

    # Remove leaving player
    leave-messages.onValue (msg) ->
      ST.ships = reject (.id == msg.from), ST.ships

  setInterval (-> tick ST; ST.tick++), 1000 / SETTINGS.tickrate
  setInterval makeRenderer(ST), 1000 / SETTINGS.framerate
  bind!.onValue (keys-down) -> ST.input := keys-down
  network!

export SETTINGS
