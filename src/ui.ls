$ ->
  SETTINGS = exports.SETTINGS
  INPUT = exports.INPUT

  inputs =
    * label: "Acceleration"
      name: "acceleration"
      setting: SETTINGS.acceleration
    * label: "Rate of fire"
      name: "fire-delay"
      setting: SETTINGS.shot-delay
    * label: "Projectile speed"
      name: "projectile-speed"
      setting: SETTINGS.shot-velocity
    * label: "Projectile range"
      name: "projectile-range"
      setting: SETTINGS.shot-range
    * label: "Size"
      name: "size"
      setting: SETTINGS.ship-size
    * label: "Turning speed"
      name: "turn"
      setting: SETTINGS.turn

  store-settings = ! ->
    s = {}
    for i in inputs
      s[i.name] = $('#'+i.name).valueBar('value')
    $.cookies.set \setup, s

  setup = $.cookies.get \setup
  name = $ \<input>
    ..val if setup is not null and setup[\name] is not void then setup[\name] else \Name
    ..attr \name \name
  SETTINGS.player.name = name.val!
  nameUpdates = name.asEventStream \keyup .onValue (event) ->
    setup = $.cookies.get \setup
    setup[\name] = SETTINGS.player.name = $ event.target .val!
    $.cookies.set \setup setup
  p = $ \<p>
    ..text \Name
  fieldset = $ \fieldset
    ..append p
    ..append name

  nameUpdates = $ \#channel .asEventStream \change .onValue (event) ->
    INPUT.change-channel parseInt($ event.target .val!)
    $("[name=spawn]").removeAttr(\disabled)

  for input in inputs
    i = $ "<div id='#{input.name}'>"
    value = if setup != null then setup[input.name] else null
    if !(value != null and value != void)
      value = 4
    (!->
      setting = input.setting
      i.valueBar({value: value, max: 7, onmouseout: (->), onmouseover: (->), onchange: (value) ->
        setting.value = setting.base + (value - 4) * setting.step
        store-settings!
      })
    )()
    p = $ \<p>
    p.text input.label
    fieldset.append p
      ..append i

  spawn = $('<input type="submit" name="spawn" value="&gt;&gt;&gt; Spawn &lt;&lt;&lt;" />')
  spawn.click !(event) ->
    $(this).attr \disabled, \disabled
    INPUT.spawn!
    $ this .blur() # Blur for Firefox to gain focus on window and read keyboard input
  $ \#setup .append spawn
