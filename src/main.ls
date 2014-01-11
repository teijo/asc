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

  x = (v) ->
    if v is null
      0
    else
      v.x

  y = (v) ->
    if v is null
      0
    else
      v.y


  xy = (v) ->
    if v is null
      [0, 0]
    else
      [v.x, v.y]

  delta-timer = ->
    start = new Date!.getTime!
    prev = start
    ->
      now = new Date!.getTime!
      delta = now - prev
      prev := now
      delta

  out-of-bounding-box = (rect, v) ->
    [vx, vy] = xy(v)
    [w, h] = xy(rect)
    vx < 0 or vy < 0 or vx > w  or vy > h

  draw-world-edges = !(ctx, origo) ->
    [w, h] = xy settings.window-dimensions
    ctx
      ..save!
      ..strokeStyle = \#F00
      ..rect origo.x + 1, origo.y + 1, w - 1, h - 1
      ..stroke!
      ..restore!

  draw-viewport = !(ctx, origo, w, h) ->
    ctx
      ..save!
      ..translate origo.x, origo.y
      ..strokeStyle = \#F0F
      ..rect -w/2, -h/2, w, h
      ..stroke!
      ..restore!

  adjust-canvas-size = ! ->
    $ "canvas"
      ..attr \width window.innerWidth
      ..attr \height window.innerHeight

  time-scale = (delta-ms) ->
    (per-second) ->
      per-second * (delta-ms / 1000)

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

  make-renderer = (state) ->
    world-to-view = !(world-size, view-world-pos, window-size, ctx, vectors, closure) -->
      [virtual-view-w, virtual-view-h] = [400, 300]
      [vw, vh] = xy(window-size)
      [ww, wh] = xy(world-size)
      world-origo-in-window-x = vw / 2 - x(view-world-pos)
      world-origo-in-window-y = vh / 2 - y(view-world-pos)
      clones-to-right = 0 >? Math.ceil((virtual-view-w/2 - (ww - view-world-pos.x)) / ww)
      clones-to-left = 0 <? Math.floor((view-world-pos.x - virtual-view-w/2) / ww)
      clones-to-down = 0 >? Math.ceil((virtual-view-h/2 - (wh - view-world-pos.y)) / wh)
      clones-to-up = 0 <? Math.floor((view-world-pos.y - virtual-view-h/2) / wh)
      ctx.save!
      ctx.translate world-origo-in-window-x, world-origo-in-window-y
      if view-world-pos
        draw-viewport ctx, view-world-pos, virtual-view-w, virtual-view-h
      for xi in [clones-to-left to clones-to-right]
        for yi in [clones-to-up to clones-to-down]
          vs = vectors.map (v) ->
            new THREE.Vector2!.fromArray [
              v.x + xi * ww,
              v.y + yi * wh]
          closure ctx, vs
      ctx.restore!

    viewport-size = ->
      new THREE.Vector2!.fromArray [window.innerWidth, window.innerHeight]

    batch = (ctx, closure) ->
      ctx.save!
      closure ctx
      ctx.restore!

    path = (ctx, closure) ->
      ctx.beginPath!
      closure ctx
      ctx.closePath!
      ctx.stroke!

    canvas =  $ "<canvas>" .appendTo $ \#game
      ..attr \width window.innerWidth
      ..attr \height window.innerHeight
    c = canvas[0].getContext \2d
      ..lineCap = \round
      ..lineWidth = 0

    player-position = (ships) ->
      player = find (-> it.id is void), ships
      if player is not void
        player.position
      else
        null

    world-size = settings.window-dimensions

    draw-shot = (ctx, v) ->
      batch ctx, ->
        ctx.translate x(v), y(v)
        path ctx, ->
          ctx.arc 0, 0, 4, 0, util.PI2

    draw-ship = !(ctx, diameter, pos, heading, color) ->
      ctx.save!
      ctx.translate x(pos), y(pos)
      ctx.strokeStyle = color
      path ctx, ->
        ctx.arc 0, 0, diameter, 0, util.PI2
      path ctx, ->
        ctx.moveTo 0, 0
        ctx.lineTo x(heading) * 50, y(heading) * 50
      ctx.restore!

    draw-ship-hud = (ctx, name, x, y, energy) ->
      ctx
        ..fillStyle = \#C0C
        ..fillText name, x - 30, y - 54
        ..fillStyle = \#0C0
        ..strokeRect x - 30, y - 50, 60, 4
        ..fillRect x - 30, y - 50, (energy/settings.max-energy*60), 4

    draw-shots = (ctx, draw-vectors, ships) ->
      for ship in ships
        for shot in ship.shots when shot.removed is false
          draw-vectors [shot.position], (ctx, vs) ->
            v = vs |> head
            draw-shot ctx, v

    draw-ships = (ctx, draw-vectors, ships) ->
      for ship in ships
        draw-vectors [ship.position], (ctx, vs) ->
          [x, y] = xy(vs[0])
          batch ctx, ->
            color = if ship.id is void then \#00F else \#600
            draw-ship ctx, ship.diameter.value, vs[0], ship.heading, color
          draw-ship-hud ctx, ship.player.name, x, y, ship.energy

    (timestamp) ->
      offset = (player-position state.ships) ? util.ZERO2
      draw-vectors = world-to-view world-size, offset, viewport-size!, c

      c.clearRect 0, 0, c.canvas.width, c.canvas.height
      draw-vectors [util.ZERO2], (ctx, vs) ->
        draw-world-edges ctx, vs[0]

      draw-shots c, draw-vectors, state.ships
      draw-ships c, draw-vectors, state.ships

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
  renderer = make-renderer(st)
  setInterval (-> tick connection, st, tick-delta!, renderer; st.tick++), 1000 / settings.tickrate
  bind!.onValue (keys-down) -> st.input := keys-down
