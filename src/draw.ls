define ['state', 'settings', 'util'], (state, settings, util) ->
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

  batch = (ctx, closure) ->
    ctx.save!
    closure ctx
    ctx.restore!

  path = (ctx, closure) ->
    ctx.beginPath!
    closure ctx
    ctx.closePath!
    ctx.stroke!

  size = util.viewport-size!
  canvas =  $ "<canvas>" .appendTo $ \#game
    ..attr \width size.x
    ..attr \height size.y
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

  draw-touch-circle = (ctx, x, y) ->
    alpha = if state.click-state.primary then 0.1 else 0.2
    ctx
      ..beginPath!
      ..fillStyle = "rgba(0, 0, 0, #{alpha})"
      ..arc x, y, settings.touch-ship-radius, 0, util.PI2
      ..fill!
      ..closePath!

  (timestamp) ->
    offset = (player-position state.ships) ? util.ZERO2
    viewport = util.viewport-size!
    draw-vectors = world-to-view world-size, offset, viewport, c

    c.clearRect 0, 0, c.canvas.width, c.canvas.height
    draw-vectors [util.ZERO2], (ctx, vs) ->
      draw-world-edges ctx, vs[0]

    draw-touch-circle c, viewport.x / 2, viewport.y / 2

    draw-shots c, draw-vectors, state.ships
    draw-ships c, draw-vectors, state.ships

    path c, ->
      c.strokeStyle = if state.click-state.secondary then \#0F0 else \#F00
      c.moveTo viewport.x / 2, viewport.y / 2
      c.lineTo state.pointer.x, state.pointer.y
