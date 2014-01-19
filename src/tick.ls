define ['settings', 'util', 'net', 'state', 'draw', 'input'], (settings, util, connection, state, renderer, input) ->
  flush = (.filter (.removed == false))

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

  as-vector3 = (vector2) ->
    new THREE.Vector3 vector2.x, vector2.y, 0

  sign = (number) ->
    number = Math.round(number)
    if number < 0
      -1
    else if number > 0
      1
    else
      0

  try-shot = (state, player) ->
    if state.tick - player.shot-tick > settings.shot-delay.value
      player.shot-tick = state.tick
      player.shots.push {
        position: player.position.clone!
        distance: 0
        max-distance: settings.shot-range.value
        dir: player.heading.clone!.normalize!.multiplyScalar(settings.shot-velocity.value)
        removed: false
      }

  !(delta) ->
    adjust = util.time-scale delta
    player = state.ships[0]
    angle = 0
    if player is not void
      a = as-vector3(util.viewport-size!.multiplyScalar(0.5))
      b = a.clone().add(as-vector3(player.heading))
      m = new THREE.Vector3!.fromArray [state.pointer.x, state.pointer.y, 0]
      angle = sign(new THREE.Vector3().crossVectors(b.sub(a), m.sub(a)).z)

    for entry in state.queue
      connection.send(entry.id, entry.data, 0)
    state.queue = []

    if player and player.id is void
      velocity-change = player.heading.clone!.multiplyScalar adjust(settings.acceleration.value)

      if state.click-state.primary
        player.velocity.add velocity-change
        if angle < 0
          rotate-vector2 player.heading, adjust(-settings.turn.value)
        else if angle > 0
          rotate-vector2 player.heading, adjust(settings.turn.value)

      if state.click-state.secondary
        try-shot state, player

      for key in state.input
        switch key.code
        | input.key.esc.code   =>
          if player.energy > 0
            player.energy = 0
            connection.send(\DEAD, by: player.id)
            $('input[name=spawn]').removeAttr \disabled
            $ \#setup .removeClass \hidden
        | input.key.up.code    => player.velocity.add velocity-change
        | input.key.down.code  => player.velocity.sub velocity-change
        | input.key.left.code  => rotate-vector2 player.heading, adjust(-settings.turn.value)
        | input.key.right.code => rotate-vector2 player.heading, adjust(settings.turn.value)
        | input.key.space.code => try-shot state, player

      if state.input.length > 0 or state.click-state.primary
        state.input-dirty = true
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

    state.ships = reject (.energy <= 0), state.ships

    window.requestAnimationFrame renderer
