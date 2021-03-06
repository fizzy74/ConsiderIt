require './shared'
require './customizations'
require './histogram'
require './slider'
require './permissions'
require './watch_star'
require './bubblemouth'


pad = (num, len) -> 
  str = num
  dec = str.split('.')
  i = 0 
  while i < len - dec[0].toString().length
    dec[0] = "0" + dec[0]
    i += 1

  dec[0] + if dec.length > 0 then '.' + dec[1] else ''

window.CollapsedProposal = ReactiveComponent
  displayName: 'CollapsedProposal'

  render : ->
    proposal = fetch @props.proposal
    options = @props.options

    col_sizes = column_sizes
                  width: @props.width

    current_user = fetch '/current_user'

    watching = current_user.subscriptions[proposal.key] == 'watched'

    return if !watching && fetch('homepage_filter').watched

    your_opinion = fetch proposal.your_opinion
    if your_opinion?.published
      can_opine = permit 'update opinion', proposal, your_opinion
    else
      can_opine = permit 'publish opinion', proposal

    draw_slider = can_opine > 0 || your_opinion?.published

    icons = customization('show_proposer_icon', proposal) && !@props.hide_icons
    slider_regions = customization('slider_regions', proposal)
    show_proposal_scores = !@props.hide_scores && customization('show_proposal_scores', proposal)

    opinions = opinionsForProposal(proposal)

    if draw_slider
      slider = fetch "homepage_slider#{proposal.key}"
    else 
      slider = null 

    if slider && your_opinion && slider.value != your_opinion.stance && !slider.has_moved 
      # Update the slider value when the server gets back to us
      slider.value = your_opinion.stance
      if your_opinion.stance
        slider.has_moved = true
      save slider

    # sub_creation = new Date(fetch('/subdomain').created_at).getTime()
    # creation = new Date(proposal.created_at).getTime()
    # opacity = .05 + .95 * (creation - sub_creation) / (Date.now() - sub_creation)

    can_edit = permit('update proposal', proposal) > 0

    just_you = fetch('filtered').current_filter?.label == 'just you'
    everyone = fetch('filtered').current_filter?.label == 'everyone'

    slider_interpretation = (value) => 
      if value > .03
        "#{(value * 100).toFixed(0)}% #{get_slider_label("slider_pole_labels.support", proposal)}"
      else if value < -.03 
        "#{-1 * (value * 100).toFixed(0)}% #{get_slider_label("slider_pole_labels.oppose", proposal)}"
      else 
        translator "engage.slider_feedback.neutral", "Neutral"
    LI
      key: proposal.key
      id: 'p' + proposal.slug.replace('-', '_')  # Initial 'p' is because all ids must begin 
                                           # with letter. seeking to hash was failing 
                                           # on proposals whose name began with number.
      style: _.defaults {}, (@props.wrapper_style or {}),
        minHeight: 84
        position: 'relative'
        margin: "0 0 #{if can_edit then '0' else '15px'} 0"
        padding: 0
        listStyle: 'none'

      onMouseEnter: => 
        if draw_slider
          @local.hover_proposal = proposal.key; save @local
      onMouseLeave: => 
        if draw_slider && !slider.is_moving
          @local.hover_proposal = null; save @local
      onFocus: => 
        if draw_slider
          @local.hover_proposal = proposal.key; save @local
      onBlur: => 
        if draw_slider && !slider.is_moving
          @local.hover_proposal = null; save @local

      DIV 
        style: 
          width: col_sizes.first 
          display: 'inline-block'
          verticalAlign: 'top'
          position: 'relative'

        DIV 
          style: 
            position: 'absolute'
            left: if icons then -40 - 18
            top: if icons then 4


          if icons
            editor = proposal_editor(proposal)
            # Person's icon
            if editor 
              A
                href: proposal_url(proposal)
                'aria-hidden': true
                tabIndex: -1
                Avatar
                  key: editor
                  user: editor
                  style:
                    height: 40
                    width: 40
                    borderRadius: 0
                    backgroundColor: '#ddd'
                    # opacity: opacity
            else 
              SPAN 
                style: 
                  height: 50
                  width: 50
                  display: 'inline-block'
                  verticalAlign: 'top'
                  border: "2px dashed #ddd"
          else
            @props.icon?() or SVG 
              style: 
                position: 'relative'
                left: -22
                top: 3
              width: 8
              viewBox: '0 0 200 200' 
              CIRCLE cx: 100, cy: 100, r: 80, fill: '#000000'



        # Name of Proposal
        DIV
          style:
            display: 'inline-block'
            fontWeight: 400
            paddingBottom: if !can_edit then 20 else 4
            width: col_sizes.first

          A
            className: 'proposal proposal_homepage_name'
            style: _.defaults {}, (@props.name_style or {}),
              fontWeight: 600
              textDecoration: 'underline'
              #borderBottom: "1px solid #444"  
              color: '#000'            
              fontSize: 20
              
            href: proposal_url(proposal, just_you)

            proposal.name

          DIV 
            style: 
              fontSize: 12
              color: 'black' #'#999'
              marginTop: 4
              #fontStyle: 'italic'

            if customization('proposal_meta_data')
              customization('proposal_meta_data')(proposal)

            else if !@props.hide_metadata && customization('show_proposal_meta_data')
              show_author_name_in_meta_data = !icons && (editor = proposal_editor(proposal)) && editor == proposal.user

              SPAN 
                style: 
                  paddingRight: 16

                if !show_author_name_in_meta_data
                  "Added: "
                
                prettyDate(proposal.created_at)


                SPAN 
                  style: 
                    padding: '0 8px'
                  '|'

                if show_author_name_in_meta_data
                  [ 
                    SPAN 
                      style: {}
                      TRANSLATE
                        id: 'engage.proposal_author'
                        name: fetch(editor)?.name 
                        " by {name}"

                    SPAN 
                      style: 
                        padding: '0 8px'
                      '|'
                  ]



                if customization('discussion_enabled',proposal)
                    A 
                      href: proposal_url(proposal, true)
                      style: 
                        #fontWeight: 500
                        cursor: 'pointer'

                      TRANSLATE
                        id: "engage.point_count"
                        cnt: proposal.point_count

                        "{cnt, plural, one {# consideration} other {# considerations}}"

                      if proposal.active 
                        [
                          SPAN 
                            style: 
                              padding: '0 8px'
                            '|'

                          SPAN 
                            style: 
                              textDecoration: 'underline'
                            TRANSLATE
                              id: "engage.add_your_own"

                              "add a consideration"
                        ]



            if @props.show_category && proposal.cluster
              cluster = proposal.cluster 
              if fetch('/subdomain').name == 'dao' && proposal.cluster == 'Proposals'
                cluster = 'Ideas'

              if cluster == "Proposals"
                cluster = translator "engage.default_proposals_list", "Proposals"
              else 
                cluster = translator 
                             id: "proposal_list.#{cluster}"
                             key: "/translations/#{fetch('/subdomain').name}"
                             cluster 

              SPAN 
                style: 
                  #border: "1px solid #{@props.category_color}"
                  #backgroundColor: @props.category_color
                  padding: '1px 2px'
                  #color: 'white' #@props.category_color
                  fontStyle: 'italic'
                  #fontSize: 12

                cluster

            if !proposal.active
              SPAN 
                style: 
                  padding: '0 16px'

                TRANSLATE "engage.proposal_closed.short", 'closed'


          if can_edit
            DIV
              style: 
                visibility: if !@local.hover_proposal then 'hidden'
                position: 'relative'
                top: -2

              A 
                href: "#{proposal.key}/edit"
                style:
                  marginRight: 10
                  color: focus_color()
                  backgroundColor: 'transparent'
                  padding: 0
                  fontSize: 12
                TRANSLATE 'engage.edit_button', 'edit'

              if permit('delete proposal', proposal) > 0
                BUTTON
                  style:
                    marginRight: 10
                    color: focus_color()
                    backgroundColor: 'transparent'
                    border: 'none'
                    padding: 0
                    fontSize: 12

                  onClick: => 
                    if confirm('Delete this proposal forever?')
                      destroy(proposal.key)
                      loadPage('/')
                  TRANSLATE 'engage.delete_button', 'delete'




      # Histogram for Proposal
      DIV 
        style: 
          display: 'inline-block' 
          position: 'relative'
          top: -26
          verticalAlign: 'top'
          width: col_sizes.second
          marginLeft: col_sizes.gutter
                

        Histogram
          key: "histogram-#{proposal.slug}"
          proposal: proposal
          opinions: opinions
          width: col_sizes.second
          height: 40
          enable_individual_selection: !browser.is_mobile
          enable_range_selection: everyone && !browser.is_mobile
          draw_base: true
          draw_base_labels: !slider_regions
          selection_state: 'filtered'

        Slider 
          base_height: 0
          draw_handle: !!draw_slider
          key: "homepage_slider#{proposal.key}"
          width: col_sizes.second
          polarized: true
          regions: slider_regions
          respond_to_click: false
          base_color: 'transparent'
          handle: slider_handle.triangley
          handle_height: 18
          handle_width: 21
          handle_style: 
            opacity: if fetch('filtered').current_filter?.label != "just you" && !browser.is_mobile && @local.hover_proposal != proposal.key && !@local.slider_has_focus then 0 else 1             
          offset: true
          handle_props:
            use_face: false
          label: translator
                    id: "engage.slider.instructions"
                    negative_pole: get_slider_label("slider_pole_labels.oppose", proposal)
                    positive_pole: get_slider_label("slider_pole_labels.support", proposal)
                    "Express your opinion on a slider from {negative_pole} to {positive_pole}"
          onBlur: (e) => @local.slider_has_focus = false; save @local
          onFocus: (e) => @local.slider_has_focus = true; save @local 

          readable_text: slider_interpretation
          onMouseUpCallback: (e) =>
            # We save the slider's position to the server only on mouse-up.
            # This way you can drag it with good performance.
            if your_opinion.stance != slider.value

              # save distance from top that the proposal is at, so we can 
              # maintain that position after the save potentially triggers 
              # a re-sort. 
              prev_offset = @getDOMNode().offsetTop
              prev_scroll = window.scrollY

              your_opinion.stance = slider.value
              your_opinion.published = true
              save your_opinion
              window.writeToLog 
                what: 'move slider'
                details: {proposal: proposal.key, stance: slider.value}
              @local.slid = 1000

              update = fetch('homepage_you_updated_proposal')
              update.dummy = !update.dummy
              save update

            mouse_over_element = closest e.target, (node) => 
              node == @getDOMNode()

            if @local.hover_proposal == proposal.key && !mouse_over_element
              @local.hover_proposal = null 
              save @local
    
      # little score feedback
      if show_proposal_scores
        score = 0
        filter_out = fetch 'filtered'
        opinions = (o for o in opinions when filter_out.enable_comparison || !filter_out.users?[o.user])

        for o in opinions 
          score += o.stance
        avg = score / opinions.length
        negative = score < 0
        score *= -1 if negative

        score = pad score.toFixed(1),2

        val = "0000 opinion#{if opinions.length != 1 then 's' else ''}"
        score_w = widthWhenRendered(' opinion' + (if opinions.length != 1 then 's' else ''), {fontSize: 12}) + widthWhenRendered("0000", {fontSize: 20})

        show_tooltip = => 
          if opinions.length > 0
            tooltip = fetch 'tooltip'
            tooltip.coords = $(@refs.score.getDOMNode()).offset()
            tooltip.tip = translator({id: "engage.proposal_score_summary.explanation", percentage: Math.round(avg * 100)}, "Average rating is {percentage}%")
            save tooltip
        hide_tooltip = => 
          tooltip = fetch 'tooltip'
          tooltip.coords = null
          save tooltip

        DIV 
          'aria-hidden': true
          ref: 'score'
          style: 
            position: 'absolute'
            right: -18 - score_w
            top: 23 #40 - 12
            textAlign: 'left'

          onFocus: show_tooltip
          onMouseEnter: show_tooltip
          onBlur: hide_tooltip
          onMouseLeave: hide_tooltip

          SPAN 
            style: 
              color: '#999'
              fontSize: 20
              #fontWeight: 600
              cursor: 'default'
              lineHeight: 1

            TRANSLATE
              id: "engage.proposal_score_summary"
              small: 
                component: SPAN 
                args: 
                  style: 
                    color: '#999'
                    fontSize: 12
                    cursor: 'default'
                    verticalAlign: 'baseline'
              num_opinions: opinions.length 
              "{num_opinions, plural, =0 {<small>no opinions</small>} one {# <small>opinion</small>} other {# <small>opinions</small>} }"


