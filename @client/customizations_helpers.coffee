window.passes_tags = (user, tags) -> 
  if typeof(tags) == 'string'
    tags = [tags]
  user = bus_fetch(user)

  passes = true 
  for tag in tags 
    passes &&= !!(user?.tags?[tag] && !("#{user?.tags?[tag]}".toLowerCase() in ['no', 'No', 'False', 'false', false]))

  passes 

window.passes_tag_filter = (user, tag, regex) -> 
  user = bus_fetch(user)
  return !!user?.tags?[tag]?.match(regex) 
  

window.cluster_link = (href, anchor) ->
  anchor ||= href 
  "<a href='#{href}' target='_blank' style='font-weight: 600; text-decoration:underline'>#{anchor}</a>"



#################
# PRO/CON LABELS

window.point_labels = 

  pro_con: 
    translate: true
    pro: 'pro'
    pros: 'pros' 
    con: 'con'
    cons: 'cons'
    your_header: "Give your {arguments}" 
    other_header: "Others' {arguments}" 
    top_header: "Top {arguments}" 

  strengths_weaknesses: 
    translate: true    
    pro: 'strength'
    pros: 'strengths' 
    con: 'weakness'
    cons: 'weaknesses'
    your_header: "{arguments}" 
    other_header: "{arguments} observed" 
    top_header: "Top {arguments}" 


window.get_point_label = (id, proposal) -> 
  prop = id.split('.')?[1] or id

  if proposal
    conf = customization('point_labels', proposal)
  else 
    conf = customization('point_labels')

  val = conf[prop]

  if !val 
    ""
  else
    translator 
      id: "point_labels.#{val}"
      local: !conf.translate
      val 


#####################
# SLIDER POLE LABELS

window.get_slider_label = (id, proposal, subdomain) -> 
  side = id.split('.')?[1] or id

  if proposal
    conf = customization('slider_pole_labels', proposal, subdomain)
  else 
    conf = customization('slider_pole_labels', null, subdomain)

  label = conf[side]
  if !label 
    ""
  else
    translator 
      id: "sliders.pole.#{label}"
      local: !conf.translate
      label 



window.positive_scale = (value, proposal) ->  
  value = (value + 1) / 2
  conf = customization('slider_pole_labels', proposal, bus_fetch('/subdomain'))
  "#{Math.round(value * 100)}% #{conf.support}"


window.fully_firmly_slightly_scale = (value, proposal) ->
  if Math.abs(value) < 0.02
    translator
      id: "sliders.feedback.neutral"
      "You are neutral"
  else 
    valence = get_slider_label (if value > 0 then 'support' else 'oppose'), proposal

    degree = Math.abs value
    strength_of_opinion = if degree > .999
                            "Fully"
                          else if degree > .5
                            "Firmly"
                          else
                            "Slightly" 
    
    translator
      id: "sliders.feedback.#{strength_of_opinion}"
      strength_of_opinion: strength_of_opinion
      valence: valence
      "You #{strength_of_opinion} {valence}"


window.slider_labels = 

  agree_disagree:
    translate: true
    support: 'Agree'
    oppose: 'Disagree'

    slider_feedback: "fully_firmly_slightly_scale"

  support_oppose:
    translate: true    
    support: 'Support'
    oppose: 'Oppose'

    slider_feedback: "fully_firmly_slightly_scale"

  priority:
    translate: true    
    support: 'High Priority'
    oppose: 'Low Priority'    

    slider_feedback: positive_scale

  important_unimportant:
    translate: true    
    support: 'More Important'
    oppose: 'Less Important'    

  relevance:
    support: 'Big impact!'
    oppose: 'No impact on me'    

  interested:
    support: 'More Interesting'
    oppose: 'Less Interesting'    



  yes_no:
    support: 'Yes'
    oppose: 'No'    

  strong_weak:
    support: 'Strong'
    oppose: 'Weak'    

  promising_weak:
    support: 'Promising'
    oppose: 'Weak'    


  ready_not_ready:
    support: 'Ready'
    oppose: 'Not ready'

  plus_minus:
    support: '+'
    oppose: '–'

  effective_ineffective:
    support: 'Effective'
    oppose: 'Ineffective'




##########################
# RANDOM COMPONENTS

window.ExpandableSection = ReactiveComponent
  displayName: 'ExpandableSection'

  render: -> 
    label = @props.label
    text = @props.text 

    expanded = @local.expanded 

    symbol = if expanded then 'fa-chevron-down' else 'fa-chevron-right'

    DIV null,
        

      DIV 
        onClick: => @local.expanded = !@local.expanded; save(@local)

        style: 
          fontWeight: 600
          color: @props.text_color or 'black'
          cursor: 'pointer'
          marginTop: 12
          fontSize: 22

        SPAN 
          className: "fa #{symbol}"
          style: 
            opacity: .7
            position: 'relative'
            left: -3
            paddingRight: 6
            display: 'inline-block'
            width: 20


        SPAN 
          style: {}

          label 

      if expanded 
        text 

