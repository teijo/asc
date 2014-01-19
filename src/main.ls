prelude.installPrelude window

requirejs.config {baseUrl: '.'}

requirejs ['state', 'util', 'ui', 'draw', 'net', 'settings', 'tick', 'input'], (st, util, ui, draw, network, settings, tick, input)->
  adjust-canvas-size = ! ->
    size = util.viewport-size!
    $ "canvas"
      ..attr \width size.x
      ..attr \height size.y

  touch-primary = (event) ->
    touch = event.touches[0]
    # touchend doesn't have 'touch' object, can be ignored as both touch
    # streams anyway map to false when touch ends
    distance = if touch then pointer-distance(touch.screenX, touch.screenY) else 0
    distance <= settings.touch-ship-radius

  touch-secondary = (event) ->
    !touch-primary event

  bindPointer = (input-events) ->
    if input.is-touch
      start = input-events('touchstart').do (ev) ->
        ev.preventDefault!
      input-events('touchmove').merge(start).filter(touch-secondary).map (ev) ->
        touch = ev.touches[0]
        x: touch.screenX
        y: touch.screenY
    else
      input-events('mousemove').map (ev) ->
        x: ev.x
        y: ev.y

  pointer-distance = (x, y) ->
    util.viewport-size!.clone!.multiplyScalar(0.5).sub(new THREE.Vector2(x, y)).length!

  mouse-primary = (event) ->
    event.button is 0

  mouse-secondary = (event) ->
    event.button is 2

  bindClickState = (input-events) ->
    [start, end, primary, secondary] = if input.is-touch
      then ['touchstart', 'touchend', touch-primary, touch-secondary]
      else ['mousedown', 'mouseup', mouse-primary, mouse-secondary]

    starts = input-events(start)
    primary-downs = starts.filter(primary).map(true)
    secondary-downs = starts.filter(secondary).map(true)

    # Template change triggered twice as both touch streams are mapped to false
    ends = input-events(end)
    primary-ups = if input.is-touch
      then ends.map(false)
      else ends.filter(primary).map(false)
    secondary-ups = if input.is-touch
      then ends.map(false)
      else ends.filter(secondary).map(false)

    Bacon.combineTemplate {
      primary: primary-downs.merge(primary-ups).toProperty(false)
      secondary: secondary-downs.merge(secondary-ups).toProperty(false)
    } .changes!

  bindKeys = ->
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
    state(input.key.up)
      .combine state(input.key.down), concat
      .combine state(input.key.left), concat
      .combine state(input.key.right), concat
      .combine state(input.key.space), concat
      .combine state(input.key.esc), concat

  tick-delta = util.delta-timer!
  setInterval (-> tick tick-delta!; st.tick++), 1000 / settings.tickrate
  bindKeys!.onValue (keys-down) -> st.input := keys-down

  canvas = document.getElementsByTagName('canvas')[0]
  canvas.addEventListener 'contextmenu', -> it.preventDefault!; false
  input-events = Bacon.fromEventTarget canvas, _
  bindPointer(input-events).onValue ->
    st.pointer.x = it.x
    st.pointer.y = it.y
  bindClickState(input-events).onValue ->
    st.click-state = it
