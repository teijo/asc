prelude.installPrelude window

SLIDER =
  from: -3
  to: 3
  step: 1
  scale: [\-3, \-2, \-1, \0, \+1, \+2, \+3]
  smooth: false
  dimension: ''
  skin: "yellow"
  calculate: (value) ->
    if value > 0 then "+"+value else value
  callback: ->
    total = 0
    for i in $ \input
      total -= parseInt($(i).val())
    $ "h2 span" .text if total > 0 then "+"+total else total

$ ->
  inputs = [
    {
      label: "Acceleration"
      name: "acceleration"
    }, {
      label: "Maximum speed"
      name: "speed"
    }, {
      label: "Rate of fire"
      name: "fire-delay"
    }, {
      label: "Projectile speed"
      name: "projectile-speed"
    }, {
      label: "Size"
      name: "size"
    }, {
      label: "Turning speed"
      name: "turn"
    }
  ]
  fieldset = $ \fieldset

  for input in inputs
    i = $ \<input>
    p = $ \<p>
    p.text input.label
    i.name = input.name
    i.val 0
    fieldset.append p
    fieldset.append i

  $input = $("input")
  $input.slider(SLIDER)
  h2 = $ \<h2>
  h2.html "Handicap: <span>0</span>"
  fieldset.append h2
