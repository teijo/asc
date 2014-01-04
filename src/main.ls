prelude.installPrelude window

PI2 = Math.PI*2
ZERO2 = [0, 0]

SETTINGS =
  channel: 0
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
  shot-range:
    value: null
    base: 600
    step: 100
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
  Vector.create map value-wrap, zip(vector.elements, bounding-box.elements)

$ ->
  SPAWN =
    player: SETTINGS.player
    velocity: Vector.create ZERO2
    heading: Vector.create [0, -1]
    position: SETTINGS.window-dimensions.multiply 0.5
    shots: []
    shot-tick: 0
    diameter: SETTINGS.ship-size
    energy: SETTINGS.max-energy
  ST =
    ships: []
    tick: 0
    input: []
    input-dirty: false
    queue: []

  INPUT =
    spawn: ->
      if ST.ships.length == 0 or ST.ships[0].id is not void
        ST.ships = [^^SPAWN] ++ ST.ships
        ST.input-dirty = true
      else
        throw "Must not try to spawn duplicates"
    change-channel: (new-channel, ready-cb) ->
      SETTINGS.channel = new-channel
      ST.queue.push(id: \DEAD, data: { by: 0 })
      ST.ships = []
      ST.input-dirty = true

  export INPUT

  flush = (.filter (.removed == false))

  x = (v) ->
    if v is null
      0
    else
      v.elements[0]

  y = (v) ->
    if v is null
      0
    else
      v.elements[1]


  xy = (v) ->
    if v is null
      [0, 0]
    else
      v.elements

  outOfBoundingBox = (rect, v) ->
    [vx, vy] = xy(v)
    [w, h] = xy(rect)
    vx < 0 or vy < 0 or vx > w  or vy > h

  drawWorldEdges = (ctx) ->
    [w, h] = xy SETTINGS.window-dimensions
    ctx.save!
    ctx.strokeStyle = \#F00
    ctx.rect 1, 1, w - 1, h - 1
    ctx.stroke!
    ctx.restore!

  adjustCanvasSize = ! ->
    $ "canvas"
      ..attr \width window.innerWidth
      ..attr \height window.innerHeight

  world-wrap = (position) ->
    if outOfBoundingBox SETTINGS.window-dimensions, position
      vector-wrap(SETTINGS.window-dimensions)(position)
    else
      position

  makeRenderer = (state) ->
    world-to-view = !(world-size, view-position, view-size, ctx, vectors, closure) -->
      [vw, vh] = xy(view-size)
      [ww, wh] = xy(world-size)
      x-worlds = Math.ceil(vw / ww)
      xo = vw / 2 - x(view-position)
      xwo = Math.ceil(xo / ww)
      y-worlds = Math.ceil(vh / wh)
      yo = vh / 2 - y(view-position)
      ywo = Math.ceil(yo / wh)
      ctx.save!
      ctx.translate xo, yo
      for xi in [0 to x-worlds]
        for yi in [0 to y-worlds]
          vs = vectors.map (v) ->
            Vector.create [
              v.elements[0] + (xi - xwo) * ww,
              v.elements[1] + (yi - ywo) * wh]
          closure ctx, vs
      ctx.restore!

    viewportSize = ->
      Vector.create [window.innerWidth, window.innerHeight]

    drawViewport = (ctx, center, viewport-size) ->
      [w, h] = xy(viewport-size!)
      ctx.save!
      ctx.strokeStyle = \#0FF
      ctx.translate x(center), y(center)
      ctx.rect -w/2, -h/2, w, h
      ctx.stroke!
      ctx.restore!

    batch = (ctx, closure) ->
      ctx.save!
      closure ctx
      ctx.restore!

    path = (ctx, closure) ->
      ctx.beginPath!
      closure ctx
      ctx.stroke!

    canvas =  $ "<canvas>" .appendTo $ \#game
      ..attr \width window.innerWidth
      ..attr \height window.innerHeight
    c = canvas[0].getContext \2d
      ..lineCap = \round
      ..lineWidth = 0

    playerPosition = (ships) ->
      player = find (-> it.id is void), state.ships
      if player is not void
        player.position
      else
        null

    draw-shot = (ctx, v) ->
      batch ctx, ->
        ctx.translate x(v), y(v)
        path ctx, ->
          ctx.arc 0, 0, 4, 0, PI2

    draw-ship = (ctx, diameter, pos, heading) ->
      ctx.translate x(pos), y(pos)
      path ctx, ->
        ctx.arc 0, 0, diameter, 0, PI2
      path ctx, ->
        ctx.moveTo 0, 0
        ctx.lineTo x(heading) * 50, y(heading) * 50

    draw-ship-hud = (ctx, name, x, y, energy) ->
      c
        ..fillStyle = \#C0C
        ..fillText name, x, y
        ..fillStyle = \#0C0
        ..strokeRect x - 30, y - 50, 60, 4
        ..fillRect x - 30, y - 50, (energy/SETTINGS.max-energy*60), 4

    (timestamp) ->
      offset = playerPosition state.ships
      worldSize = SETTINGS.window-dimensions
      draw-vectors = world-to-view worldSize, offset, viewportSize!, c
      c.clearRect 0, 0, c.canvas.width, c.canvas.height
      draw-vectors [], (ctx, vs) ->
        ctx.strokeStyle = \#F00
        drawWorldEdges ctx

      for ship in state.ships
        for shot in ship.shots when shot.removed is false
          draw-vectors [shot.position], (ctx, vs) ->
            v = vs |> head
            draw-shot ctx, v

        draw-vectors [ship.position], (ctx, vs) ->
          [x, y] = xy(vs[0])
          batch c, ->
            if ship.id is void
              drawViewport c, ship.position, viewportSize
            c.strokeStyle = if ship.id is void then \#00F else \#600
            draw-ship c, ship.diameter.value, vs[0], ship.heading
          draw-ship-hud c, ship.player.name, x, y, ship.energy

  tick = (connection, state, renderer) ->
    player = state.ships[0]

    for entry in ST.queue
      connection.send(entry.id, entry.data, 0)
    ST.queue = []

    if player and player.id is void
      velocity-change = player.heading.multiply SETTINGS.acceleration.value
      for key in state.input
        switch key.code
        | KEY.esc.code   =>
          if player.energy > 0
            player.energy = 0
            connection.send(\DEAD, by: player.id)
            $('input[name=spawn]').removeAttr \disabled
            $ \#setup .removeClass \hidden
        | KEY.up.code    => player.velocity = player.velocity.add velocity-change
        | KEY.down.code  => player.velocity = player.velocity.subtract velocity-change
        | KEY.left.code  => player.heading = player.heading.rotate -SETTINGS.turn.value, ZERO2
        | KEY.right.code => player.heading = player.heading.rotate SETTINGS.turn.value, ZERO2
        | KEY.space.code => \
          if state.tick - player.shot-tick > SETTINGS.shot-delay.value
            player.shot-tick = state.tick
            player.shots.push {
              position: player.position.dup!
              distance: 0
              max-distance: SETTINGS.shot-range.value
              dir: player.heading.toUnitVector!.multiply(SETTINGS.shot-velocity.value)
              removed: false
            }


      if state.input.length > 0
        ST.input-dirty = true
        if player.velocity.distanceFrom(ZERO2) > SETTINGS.max-velocity
          player.velocity = player.velocity.toUnitVector!.multiply SETTINGS.max-velocity

    for ship in state.ships
      ship.position = world-wrap ship.position.add(ship.velocity)
      for shot in ship.shots when shot.removed is false
        shot.distance += shot.dir.distanceFrom(ZERO2)
        shot.position = shot.position.add(shot.dir)
        diff = SETTINGS.window-dimensions.subtract(shot.position)
        if shot.distance > shot.max-distance
          shot.removed = true
          continue
        shot.position = world-wrap shot.position
        for enemy in state.ships
          if enemy.id == ship.id
            continue
          if shot.position.distanceFrom(enemy.position) < enemy.diameter.value
            shot.removed = true
            enemy.energy--
            if enemy.id is void and enemy.energy <= 0
              connection.send(\DEAD, by: ship.id)
              $('input[name=spawn]').removeAttr \disabled
              $ \#setup .removeClass \hidden

      ship.shots = ship.shots |> flush

    ST.ships = reject (.energy <= 0), ST.ships

    window.requestAnimationFrame renderer

  bind = ->
    Bacon.fromEventTarget(window, 'resize').throttle(100).onValue adjustCanvasSize
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
        max-distance: SETTINGS.shot-range.value
        position: strip-decimals it.position.elements, 1
        dir: strip-decimals it.dir.elements, 5), ship.shots
      energy: ship.energy
      diameter: ship.diameter.value
      velocity: strip-decimals ship.velocity.elements, 5
      heading: strip-decimals ship.heading.elements, 5
      position: strip-decimals ship.position.elements, 2

    deserialize = (msg) ->
      ship = msg.data
      {
        id: msg.from
        player:
          name: ship.name
        shots: map (->
          distance: it.distance
          max-distance: it.max-distance
          position: Vector.create it.position
          dir: Vector.create it.dir
          removed: false), ship.shots
        energy: ship.energy
        diameter:
          value: ship.diameter
        velocity: Vector.create ship.velocity
        heading: Vector.create ship.heading
        position: Vector.create ship.position
      }

    # Wrap WebSocket events in Bacon and make send() a JSON serializer
    connection = (url) ->
      ws = new WebSocket url
      update = new Bacon.Bus!
      update.filter -> it is not void
         .map serialize
         .map (-> id: \UPDATE, channel: SETTINGS.channel, data: it)
         .map JSON.stringify
         .onValue (-> ws.send it)
      out = new Bacon.Bus!
      out.map JSON.stringify
         .onValue (-> ws.send it)
      fields = map -> [it], [\onopen \onclose \onerror \onmessage]
      field-bus-pairs = each (-> bus = new Bacon.Bus!; ws[it] = bus.push; it.push -> bus), fields
      methods = field-bus-pairs |> listToObj
      methods.update = update.push
      methods.send = (id, data, channel = SETTINGS.channel) -> out.push(id: id, channel: channel, data: data)
      methods

    ws = connection 'ws://'+SETTINGS.server+'/game'
    ws.onopen!.onValue !-> setInterval (->
      if ST.input-dirty
        ws.update find (.id is void), ST.ships
        ST.input-dirty = false), SETTINGS.state-throttle
    ws.onerror!.onValue log

    ws-connected = ws.onopen!.map true
    ws-disconnected = ws.onclose!.map false
    ws-connected.merge(ws-disconnected)
                .onValue (is-connected) ->
                  $ \.connected .toggle is-connected
                  $ \.disconnected .toggle !is-connected

    # Flush everyone else on disconnect
    ws-disconnected.onValue !-> ST.ships = take 1, ST.ships

    all-messages = ws.onmessage!.map (.data)
                                .do (-> if SETTINGS.dump then log(it))
                                .map JSON.parse
                                .filter ((it) -> it.channel == 0 || it.channel == SETTINGS.channel)
    state-messages = all-messages .filter (.id == \UPDATE)
    dead-messages = all-messages .filter (.id == \DEAD)
    leave-messages = all-messages .filter (.id == \LEAVE)

    dead-messages .onValue (msg) ->
      ST.ships = reject (.id == msg.from), ST.ships

    # Create or update another player
    state-messages .map deserialize .onValue (ship) ->
      existing-ship = find (-> it.id != void and it.id == ship.id), ST.ships
      if existing-ship is void
        ST.ships.push ship
        ST.input-dirty = true
      else
        existing-ship <<< ship

    # Remove leaving player
    leave-messages.onValue (msg) ->
      ST.ships = reject (.id == msg.from), ST.ships

    ws

  connection = network!
  renderer = makeRenderer(ST)
  setInterval (-> tick connection, ST, renderer; ST.tick++), 1000 / SETTINGS.tickrate
  bind!.onValue (keys-down) -> ST.input := keys-down

export SETTINGS
