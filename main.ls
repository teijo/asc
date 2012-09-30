prelude.installPrelude window

PI2 = Math.PI*2
ZERO2 = [0, 0]

SETTINGS =
  window-dimensions: Vector.create [800, 600]
  acceleration: 0.04
  turn: 0.04
  shot-velocity: 4.0
  shot-delay: 10

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

$ ->
  ST =
    ships: [
      velocity: Vector.create ZERO2
      heading: Vector.create [0, -1]
      position: SETTINGS.window-dimensions.multiply 0.5
      shots: []
      shot-tick: 0
    ]
    tick: 0
    input: []

  makeRenderer = (state) ->
    batch = (ctx, closure) ->
      ctx.save!
      closure ctx
      ctx.restore!

    path = (ctx, closure) ->
      ctx.beginPath!
      closure ctx
      ctx.stroke!

    canvas =  $ \canvas .appendTo $ \body
    canvas.attr \width SETTINGS.window-dimensions.elements[0]
    canvas.attr \height SETTINGS.window-dimensions.elements[1]
    c = canvas[0].getContext \2d
    c.lineCap = \round
    c.lineWidth = 0

    ->
      c.clearRect 0, 0, c.canvas.width, c.canvas.height
      c.strokeStyle = \#F00

      for ship in state.ships
        for shot in ship.shots
          batch c, ->
            c.translate shot.position.elements[0], shot.position.elements[1]
            path c, ->
              c.arc 0, 0, 4, 0, PI2

        batch c, ->
          c.strokeStyle = \#000
          c.translate ship.position.elements[0], ship.position.elements[1]
          path c, ->
            c.arc 0, 0, 10, 0, PI2
          path c, ->
            c.moveTo 0, 0
            c.lineTo ship.heading.elements[0] * 50, ship.heading.elements[1] * 50

  tick = (state) ->
    player = state.ships[0]
    velocity-change = player.heading.multiply SETTINGS.acceleration

    for key in state.input
      switch key.code
      | KEY.up.code    => player.velocity = player.velocity.add velocity-change
      | KEY.down.code  => player.velocity = player.velocity.subtract velocity-change
      | KEY.left.code  => player.heading = player.heading.rotate -SETTINGS.turn, ZERO2
      | KEY.right.code => player.heading = player.heading.rotate SETTINGS.turn, ZERO2
      | KEY.space.code => \
        if state.tick - player.shot-tick > SETTINGS.shot-delay
          player.shot-tick = state.tick
          player.shots.push { position: player.position.dup!, \
                                   dir: player.heading.toUnitVector!
                                              .multiply SETTINGS.shot-velocity }

    for ship in state.ships
      ship.position = ship.position.add(ship.velocity)
      for shot in ship.shots
        shot.position = shot.position.add(shot.dir)

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

  setInterval (-> tick ST; ST.tick++), 10
  setInterval makeRenderer(ST), 16 # 1000/60 -> ~60 fps
  bind!.onValue (keys-down) -> ST.input := keys-down

