prelude.installPrelude window

requirejs.config {baseUrl: '.'}

requirejs ['state', 'util', 'ui', 'draw', 'net', 'settings', 'tick', 'input'], (st, util, ui, draw, network, settings, tick, input)->
  adjust-canvas-size = ! ->
    size = util.viewport-size!
    $ "canvas"
      ..attr \width size.x
      ..attr \height size.y

  bindPointer = (input-events) ->
    if input.is-touch
      start = input-events('touchstart')
      input-events('touchmove').merge(start).map (ev) ->
        ev.preventDefault!
        touch = ev.touches[0]
        x: touch.screenX
        y: touch.screenY
    else
      input-events('mousemove').map (ev) ->
        x: ev.x
        y: ev.y

  bindClickState = (input-events) ->
    [start, end] = if input.is-touch then ['touchstart', 'touchend'] else ['mousedown', 'mouseup']
    downs = input-events(start).map(true)
    ups = input-events(end).map(false)
    downs.merge(ups).toProperty(false).changes()

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
  input-events = Bacon.fromEventTarget canvas, _
  bindPointer(input-events).onValue ->
    st.pointer.x = it.x
    st.pointer.y = it.y
  bindClickState(input-events).onValue ->
    st.click-state = it
