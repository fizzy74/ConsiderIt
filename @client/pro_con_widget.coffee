require "./opinion_views"
require "./browser_hacks"
require "./dock"
require "./list"


window.CRAFTING_TRANSITION_SPEED = 700   # Speed of transition from results to crafting (and vice versa) 


fetch 'decisionboard',
  docked : false



window.get_selected_point = -> 
  fetch('location').query_params.selected

window.getProposalMode = (proposal) -> 
  local_state = fetch shared_local_key proposal
  local_state.mode


window.update_proposal_mode = (proposal, proposal_mode, triggered_by) ->
  can_opine = canUserOpine proposal
  proposal = fetch proposal

  # permission not granted for crafting
  if proposal_mode == 'crafting' && 
      !(can_opine in [Permission.PERMITTED, Permission.UNVERIFIED_EMAIL, \
                      Permission.NOT_LOGGED_IN, Permission.INSUFFICIENT_INFORMATION] || 
       (can_opine == Permission.DISABLED && your_opinion.key))

    proposal_mode = 'results' 

  local_state = fetch shared_local_key proposal
  if local_state.mode != proposal_mode 
    local_state.mode = proposal_mode 
    save local_state


  # window.writeToLog
  #   what: 'toggle proposal mode'
  #   details: 
  #     from: getProposalMode()
  #     to: proposal_mode
  #     triggered_by: triggered_by 



responsive_style_registry.push (responsive_vars) -> 
  content_width = responsive_vars.CONTENT_WIDTH
  doc_gutter = responsive_vars.DOC_GUTTER
  w = responsive_vars.WINDOW_WIDTH
  portrait = responsive_vars.PORTRAIT_MOBILE


  ######
  # only used for crafting mode on large screens
  whitespace = Math.max(100, w / 10)
  decision_board_width = Math.min 700, content_width - 2 * doc_gutter - 2 * whitespace + 4 # the four is for the border
  ######

  point_font_size = 14

  if portrait
    point_font_size += 2

  {
    DECISION_BOARD_WIDTH: decision_board_width
    POINT_FONT_SIZE: point_font_size  
  }


styles += """
  .slow-thought {
  }

  @media (min-width: #{TABLET_BREAKPOINT}px) {
    .slow-thought {
      --POINT_COLUMN_MARGIN: 16px;
      --SLOW_WHITESPACE: max(100px, 10vw);
      --DECISION_BOARD_WIDTH: min(700px, var(--BODY_WIDTH) + 4px);
      --REASONS_AREA_WIDTH: calc( var(--OPINION_BLOCK_WRAPPER_WIDTH) );
      --REASONS_AREA_LEFT: calc(  (var(--HOMEPAGE_WIDTH) + var(--LIST_PADDING_RIGHT) + var(--LIST_PADDING_LEFT) - var(--REASONS_AREA_WIDTH)) / 2   );               
    }

    .results .slow-thought {
      --BODY_WIDTH: calc(2 * var(--ITEM_OPINION_WIDTH));
      --POINT_WIDTH: calc(var(--BODY_WIDTH) / 2 - 2 * var(--POINT_COLUMN_MARGIN) );    
    }

    .crafting .slow-thought {
      --BODY_WIDTH: calc(var(--CONTENT_WIDTH) - 2 * var(--DOC_GUTTER) - 2 * var(--SLOW_WHITESPACE));
      --POINT_WIDTH: calc(var(--DECISION_BOARD_WIDTH) / 2 - 30px);
    }

    .crafting .points_by_community {
      --POINT_WIDTH: calc( ( var(--OPINION_BLOCK_WRAPPER_WIDTH) - var(--DECISION_BOARD_WIDTH)) / 2 - 5 * var(--POINT_COLUMN_MARGIN)  );
    }

  }

  @media (max-width: #{TABLET_BREAKPOINT}px) {
    .slow-thought {
      --POINT_COLUMN_MARGIN: 9px;
      --BODY_WIDTH: var(--ITEM_OPINION_WIDTH);
    }
  }

  @media (max-width: #{TABLET_BREAKPOINT}px) and (min-width: #{PHONE_BREAKPOINT}px) {
    .slow-thought {
      --POINT_WIDTH: calc(var(--BODY_WIDTH) / 2 - 2 * var(--POINT_COLUMN_MARGIN) );
    }
  }

  @media (max-width: #{PHONE_BREAKPOINT}px) {
    .slow-thought {
      --POINT_WIDTH: calc(var(--BODY_WIDTH) / 2 - 1.5 * var(--POINT_COLUMN_MARGIN) );
    }
  }


"""




styles += """

  .slow-thought {
    position: relative;
    z-index: 1;
    opacity: 1;        
  }

  :not(.expanding).is_expanded .slow-thought {
    transition: opacity #{ANIMATION_SPEED_ITEM_EXPANSION}s linear #{STAGE1_DELAY}s;    
    opacity: 1;
  }

  .reasons_region {
    position: relative;
    padding-bottom: 4em; /* padding instead of margin for docking */
    display: flex; 
    align-items: center;
    flex-direction: column;
  }

  @media (min-width: #{TABLET_BREAKPOINT}px) {
    width: var(--REASONS_AREA_WIDTH);
    left: var(--REASONS_AREA_LEFT);
    transition: width #{CRAFTING_TRANSITION_SPEED}ms, left #{CRAFTING_TRANSITION_SPEED}ms;    
  }

  .points_by_community {
    display: inline-block;
    vertical-align: top;
    margin: 38px var(--POINT_COLUMN_MARGIN) 0 var(--POINT_COLUMN_MARGIN);
    position: relative;
  }


  @media (max-width: #{PHONE_BREAKPOINT}px) {
    .pros_by_community {
      margin-right: calc(var(--POINT_COLUMN_MARGIN) / 2);
    }

    .cons_by_community {
      margin-left: calc(var(--POINT_COLUMN_MARGIN) / 2);
    }

  }

  .points_by_community .points_heading_label, .empty-list-callout, .reasons_region .point, .give_a_point {
    opacity: 0;
  }

  :not(.expanding).is_expanded .points_by_community .points_heading_label, :not(.expanding).is_expanded .empty-list-callout, :not(.expanding).is_expanded .reasons_region .point, :not(.expanding).is_expanded .give_a_point {
    transition: opacity #{ANIMATION_SPEED_ITEM_EXPANSION}s ease #{STAGE1_DELAY}s;    
    opacity: 1;
  }


  /* for collapsed => summary transition */
  :not(.expanding).is_expanded .reasons_region :nth-child(1).point {
    transition-delay: #{STAGE1_DELAY}s;
  }

  :not(.expanding).is_expanded .reasons_region :nth-child(2).point {
    transition-delay: #{STAGE1_DELAY + 1 * ANIMATION_SPEED_ITEM_EXPANSION}s;
  }

  :not(.expanding).is_expanded .reasons_region :nth-child(3).point {
    transition-delay: #{STAGE1_DELAY + 1.5 * ANIMATION_SPEED_ITEM_EXPANSION}s;
  }

  :not(.expanding).is_expanded .reasons_region :nth-child(4).point {
    transition-delay: #{STAGE1_DELAY + 2 * ANIMATION_SPEED_ITEM_EXPANSION}s;
  }

  :not(.expanding).is_expanded .reasons_region .point {
    transition-delay: #{STAGE1_DELAY + 2.5 * ANIMATION_SPEED_ITEM_EXPANSION}s;
  }







  .slow-thought .DecisionBoard {
    opacity: 0;        
  }

  :not(.expanding).is_expanded .slow-thought .DecisionBoard {
    opacity: 1;
    transition-property: opacity; 
    transition-timing-function: ease;    
    transition-duration: #{3 * ANIMATION_SPEED_ITEM_EXPANSION}s;
    transition-delay: 0; 
  }

  :not(.expanding).is_expanded .slow-thought.summary .DecisionBoard {
    transition-delay: #{STAGE2_DELAY}s;    
  }

"""

window.Reasons = ReactiveComponent
  displayName: "Reasons"

  render: -> 


    current_user = fetch '/current_user'
    proposal = fetch @props.proposal

    your_opinion = proposal.your_opinion
    if your_opinion.key
      fetch your_opinion

    opinion_views = fetch 'opinion_views'
    just_you = opinion_views?.active_views['just_you']



    # A number of elements controlled by other components are absolutely 
    # positioned within the reasons region (e.g. discussions, decision
    # board, new point). We need to set a minheight that is large enough to 
    # encompass these elements. 
    adjustments = fetch('reasons_height_adjustment')

    minheight = 100 + (adjustments.opinion_region_height || 0)
    if get_selected_point()
      minheight += adjustments.open_point_height or 0
    if adjustments.edit_point_height
      minheight += adjustments.edit_point_height or 0


    can_opine = canUserOpine proposal

    draw_handle = can_opine != Permission.INSUFFICIENT_PRIVILEGES && 
                    (can_opine != Permission.DISABLED || your_opinion.published ) && 
                    !(!current_user.logged_in && '*' not in proposal.roles.participant)


    mode = getProposalMode(proposal)

    # if there aren't community_points, then we won't bother showing them
    community_points = (pnt for pnt in fetch("/page/#{proposal.slug}").points or [] when pnt.includers?.length > 0)
    if mode == 'crafting'
      included_points = your_opinion.point_inclusions or []
      community_points = (pnt for pnt in community_points when !_.contains(included_points, pnt.key) )
    has_community_points = community_points.length > 0 


    if get_selected_point() && !@local.show_all_points
      @local.show_all_points = true 
      save @local

    has_selection = opinion_views.active_views.single_opinion_selected || opinion_views.active_views.region_selected
    show_all_points = @local.show_all_points || mode == 'crafting' || community_points.length < 8 || has_selection

    point_cols = ['your_con_points', 'your_pro_points', 'community_cons', 'community_pros']
    edit_mode = false
    for pc in point_cols
      col = fetch(pc)
      if col.adding_new_point || col.editing_points?.length > 0
        edit_mode = pc
        break

    local_proposal = fetch shared_local_key(proposal)

    has_focus = \
      if get_selected_point()
        'point'
      else if edit_mode
        'edit point'
      else
        "opinion"

    if local_proposal.has_focus != has_focus
      local_proposal.has_focus = has_focus
      save local_proposal

    DIV 
      className: "slow-thought #{if mode == 'crafting' then 'crafting' else 'summary'}"
      style: 
        position: 'relative'
        top: -8
        minHeight: if mode == 'crafting' then 440 else 220

      #reasons
      SECTION 
        className: "reasons_region"
        style : 
          minHeight: if show_all_points then minheight     
          padding: "#{if draw_handle && !TABLET_SIZE() then '24px' else '0'} 0 0 0"
          display: if !customization('discussion_enabled', proposal) then 'none'
          overflowY: if !show_all_points then 'hidden'  
          overflowX: if !show_all_points then 'auto' 

        H2
          className: 'hidden'

          translator
            id: "engage.reasons_section_explanation"
            'Why people think what they do about the proposal'

        # Border + bubblemouth that is shown when there is a histogram selection
        if @props.is_expanded
          GroupSelectionRegion
            proposal: @props.proposal

        if !TABLET_SIZE() && customization('discussion_enabled', proposal)
          Dock
            key: 'decisionboard-dock'
            dock_key: 'decisionboard-dock'
            docked_key: 'decisionboard'            
            constraints : ['slider-dock']
            dock_on_zoomed_screens: true
            dockable : => 
              @props.is_expanded && mode == 'crafting' && can_opine > 0

            dummy: @props.is_expanded
            dummy2: WINDOW_WIDTH()
            dummy3: mode
            dummy4: can_opine

            start: 0 # -24

            stop : -> 
              reasons_region = document.querySelector('.reasons_region')
              $$.offset( reasons_region  ).top + reasons_region.offsetHeight - 20

            style: 
              position: 'absolute'
              width: DECISION_BOARD_WIDTH()
              zIndex: 0 #so that points being dragged are above opinion region
              display: 'inline-block'
              verticalAlign: 'top'
              left: '50%'
              marginLeft: -DECISION_BOARD_WIDTH() / 2


            DecisionBoard
              key: 'decisionboard'
              proposal: proposal.key

        DIV 
          style: 
            height: if !show_all_points then 750

          PointsList 
            key: 'community_cons'
            proposal: proposal.key
            reasons_key: 'community_cons'
            rendered_as: 'community_point'
            points_editable: TABLET_SIZE()
            valence: 'cons'
            points_draggable: mode == 'crafting'
            drop_target: false
            points: buildPointsList \
              proposal, 'cons', \
              (if mode == 'results' then 'score' else 'last_inclusion'), \ 
              mode == 'crafting' && !TABLET_SIZE(), \
              mode == 'crafting' || TABLET_SIZE() || (just_you && mode == 'results')
            style: 
              visibility: if !TABLET_SIZE() && mode == 'crafting' && !has_community_points then 'hidden'


          #community pros
          PointsList 
            key: 'community_pros'
            proposal: proposal.key
            reasons_key: 'community_pros'
            rendered_as: 'community_point'
            points_editable: TABLET_SIZE()
            valence: 'pros'
            points_draggable: mode == 'crafting'
            drop_target: false
            points: buildPointsList \
              proposal, 'pros', \
              (if mode == 'results' then 'score' else 'last_inclusion'), \ 
              mode == 'crafting' && !TABLET_SIZE(), \
              mode == 'crafting' || TABLET_SIZE() || (just_you && mode == 'results')
            style: 
              visibility: if !TABLET_SIZE() && mode == 'crafting' && !has_community_points then 'hidden'

      if !show_all_points
        BUTTON 
          id: "show_all_reasons"
          style: 
            backgroundColor: "#eee"
            padding: '12px 0'
            fontSize: 24
            textAlign: 'center'
            textDecoration: 'underline'
            border: 'none'
            #border: '1px solid rgba(0,0,0,.5)'                
            cursor: 'pointer'
            display: 'block'
            width: "var(--BODY_WIDTH)"
            margin: 'auto'
            position: 'relative'
            zIndex: 1

          onClick: => 
            @local.show_all_points = true 
            save @local

          TRANSLATE
            id: "engage.show_all_thoughts"
            "Show All Reasons"



      if false && edit_mode && browser.is_mobile && !embedded_demo()
        # full screen edit point mode for mobile
        valence = if edit_mode in ['community_pros', 'your_pro_points'] 
                    'pros' 
                  else 
                    'cons'
        pc = fetch edit_mode
        EditPoint 
          key: if pc.adding_new_point then "new_point_#{valence}" else pc.editing_points[0]
          point: if pc.adding_new_point then "new_point_#{valence}" else pc.editing_points[0]
          proposal: @props.proposal
          fresh: pc.adding_new_point
          valence: valence
          your_points_key: edit_mode






styles += """

  .save_opinion_button {
    display: none;
    background-color: #{focus_color()};
    width: 100%;
    margin-top: 14px;
    border-radius: 16px;
    font-size: 24px;
  }        

  .crafting .save_opinion_button {
    display: block;
  }    

  .summary .give_opinion_button {
    background-color: #{focus_color()};
    display: block;
    color: white;
    padding: .25em 18px;
    margin: 0;
    font-size: 16px;
    width: 100%;
    border-radius: 16px;
    box-shadow: none;
  }

  .crafting .give_opinion_button {
    visibility: hidden;
  }


  .DecisionBoard.transitioning .give_opinion_button {
    visibility: hidden;
  }
  .DecisionBoard.transitioning .your_points, .DecisionBoard.transitioning .save_opinion_button, .DecisionBoard.transitioning .below_save {
    display: none;
  }

"""


##
# DecisionBoard
# Handles the user's list of important points in crafting page. 
window.DecisionBoard = ReactiveComponent
  displayName: 'DecisionBoard'

  render : ->
    current_user = fetch('/current_user')
    subdomain = fetch('/subdomain')

    db = fetch('decision_board')
    proposal = fetch @props.proposal
    
    your_opinion = proposal.your_opinion
    if your_opinion.key
      fetch your_opinion

    can_opine = canUserOpine proposal

    opinion_views = fetch 'opinion_views'
    has_selection = opinion_views.active_views.single_opinion_selected || opinion_views.active_views.region_selected

    enable_opining = can_opine != Permission.INSUFFICIENT_PRIVILEGES && 
                      (can_opine != Permission.DISABLED || your_opinion.published ) && 
                      !has_selection &&
                      !(!current_user.logged_in && '*' not in proposal.roles.participant)

    return DIV null if !enable_opining

    register_dependency = fetch(namespaced_key('slider', proposal)).value 
                             # to keep bubble mouth in sync with slider

    # if there aren't points in the wings, then we won't bother showing 
    # the drop target
    wing_points = fetch("/page/#{proposal.slug}").points or [] 
    included_points = your_opinion.point_inclusions or []
    wing_points = (pnt for pnt in wing_points when !_.contains(included_points, pnt.key) )
    are_points_in_wings = wing_points.length > 0 
      
    mode = getProposalMode(proposal)

    decision_board_style =
      borderRadius: 16
      borderStyle: 'dashed'
      borderWidth: 3
      borderColor: focus_color()
      transition: if @last_proposal_mode != mode || @transitioning  
                    "transform #{CRAFTING_TRANSITION_SPEED}ms, " + \
                    "width #{CRAFTING_TRANSITION_SPEED}ms, " + \
                    "min-height #{CRAFTING_TRANSITION_SPEED}ms"
                  else
                    'none'

    if db.user_hovering_on_drop_target
      decision_board_style.borderStyle = 'solid'

    if mode == 'results'
      give_opinion_button_width = 232
      slider = fetch namespaced_key('slider', proposal)

      opinion_region_x = get_opinion_x_pos_projection
        slider_val: slider.value
        from_width: ITEM_OPINION_WIDTH() * (if !TABLET_SIZE() then 2 else 1)
        to_width: DECISION_BOARD_WIDTH()
        x_min: 60
        x_max: 60


      _.extend decision_board_style,
        borderStyle: 'solid'
        backgroundColor: focus_color()
        # borderBottom: '1px solid rgba(0,0,0,.6)'
        cursor: 'pointer'
        transform: "translate(#{opinion_region_x - give_opinion_button_width / 2}px, -10px)"
        minHeight: 32
        width: give_opinion_button_width

    else 
      _.extend decision_board_style,
        transform: "translate(0, 10px)"
        minHeight: if are_points_in_wings then 275 else 170
        width: DECISION_BOARD_WIDTH()
        # borderBottom: "#{decision_board_style.borderWidth}px dashed #{focus_color()}"
        backgroundColor: 'white'
        
    opinion_prompt = getOpinionPrompt {proposal}

    SECTION 
      ref: 'DecisionBoard'
      className:'DecisionBoard'
      style:
        width: DECISION_BOARD_WIDTH()

      onDrop : (ev) =>
        # point_key = ev.dataTransfer.getData('text/plain')
        point_key = fetch('point-dragging').point

        return if !point_key
        point = fetch point_key

        your_opinion = proposal.your_opinion

        if !your_opinion.point_inclusions || point.key not in your_opinion.point_inclusions
          your_opinion.key ?= "/new/opinion"
          your_opinion.published = true
          your_opinion.point_inclusions ?= []

          your_opinion.point_inclusions.push point.key

          save your_opinion

          window.writeToLog
            what: 'included point'
            details: 
              point: point.id

        db = fetch('decision_board')
        db.user_hovering_on_drop_target = false
        save db

        ev.preventDefault()
        ev.stopPropagation()

      onDragLeave : (ev) => 
        db = fetch('decision_board')
        if db.user_hovering_on_drop_target
          db.user_hovering_on_drop_target = false
          save db

      onDragEnter : (ev) =>
        ev.preventDefault()

      onDragOver : (ev) => 
        db = fetch('decision_board')

        if !db.user_hovering_on_drop_target
          # point_key = ev.dataTransfer.getData('text/plain') 
          point_key = fetch('point-dragging').point
          your_opinion = proposal.your_opinion
          if point_key && point_key not in (your_opinion.point_inclusions or [])
            db.user_hovering_on_drop_target = true
            save db

        ev.preventDefault() # makes it droppable, according to html5 DnD spec
        ev.stopPropagation()


      H3 
        className: 'hidden'
        style: 
          display: if !TABLET_SIZE() && mode == 'results' then 'none'

        translator 
          id: "engage.opinion_crafting_explanation" 
          proposal_name: proposal.name
          "Craft your opinion using pros and cons about {proposal_name}"

      SliderBubblemouth 
        proposal: proposal.key
        width: 34
        height: 24
        top: -24 + 18 + 3 # +18 is because of the decision board translating down 18, 3 is for its border

      DIV
        'aria-live': 'polite'
        key: 'body' 
        className:'decision_board_body'
        style: decision_board_style
        onClick: => 
          if mode == 'results' 

            can_opine = canUserOpine proposal                                  

            if can_opine > 0
              update_proposal_mode(proposal, 'crafting', 'give_opinion_button')
            else
              # trigger authentication
              reset_key 'auth',
                form: 'create account'
                goal: 'To participate, please introduce yourself.'
                after: =>
                  can_opine = canUserOpine proposal
                  if can_opine > 0 
                    update_proposal_mode(proposal, 'crafting', 'give_opinion_button')




        DIV null, 

          if mode == 'crafting'
            DIV 
              className: 'your_points'
              style: 
                padding: '0 18px'
                marginTop: -3 # To undo the 3 pixel border

              PointsList 
                key: 'your_pro_points'
                proposal: proposal.key
                reasons_key: 'your_pro_points'
                valence: 'pros'
                rendered_as: 'decision_board_point'
                points_editable: true
                points_draggable: true
                drop_target: are_points_in_wings
                points: (p for p in your_opinion.point_inclusions or [] \
                              when fetch(p).is_pro)

              PointsList 
                key: 'your_con_points'
                proposal: proposal.key
                reasons_key: 'your_con_points'
                valence: 'cons'
                rendered_as: 'decision_board_point'
                points_editable: true
                points_draggable: true
                drop_target: are_points_in_wings
                points: (p for p in your_opinion.point_inclusions or [] \
                              when !fetch(p).is_pro)


              DIV style: {clear: 'both'}

          # only shown during results, but needs to be present always for animation
          if opinion_prompt
            BUTTON
              className: 'give_opinion_button btn'
              onClick: (e) => 
                if mode != 'results'
                  e.stopPropagation() 
                  update_proposal_mode(proposal, 'crafting', 'give_opinion_button') 

              onKeyPress: (e) => 
                if e.which == 32 || e.which == 13
                  if mode != 'results'
                    e.stopPropagation() 
                    update_proposal_mode(proposal, 'crafting', 'give_opinion_button') 


              opinion_prompt



      DIV 
        key: 'footer'
        style:
          width: DECISION_BOARD_WIDTH()

        # Big bold button at the bottom of the crafting page
        BUTTON 
          className:'save_opinion_button btn'
          onClick: => update_proposal_mode(proposal, 'results', 'save_button') 
          'aria-label': translator 'engage.update_opinion_button', 'Show everyone\'s opinion'

          translator 'engage.update_opinion_button', 'Show everyone\'s opinion'

        
        if !your_opinion.key || (your_opinion.key && permit('update opinion', proposal, your_opinion) < 0)

          DIV 
            className: 'below_save'
            style: 
              display: 'none'
                      
            BUTTON 
              className:'cancel_opinion_button primary_cancel_button'
              onClick: => update_proposal_mode(proposal, 'results', 'cancel_button')

              

        if your_opinion.key && permit('update opinion', proposal, your_opinion) > 0 && mode == 'crafting'
          remove_opinion = -> 
            your_opinion.stance = 0
            your_opinion.point_inclusions = []                   
            your_opinion.published = false 
            save your_opinion

          DIV 
            className: 'below_save'
                      
            BUTTON 
              style: 
                textDecoration: 'underline'
              className:'cancel_opinion_button primary_cancel_button'
              onClick: remove_opinion

              translator "engage.remove_my_opinion", 'Remove your opinion'



  componentDidUpdate : ->
    @transition()

  componentDidMount : ->
    @transition()

  componentWillUnmount: -> 
    @dismounting = true


  update_reasons_height: -> 
    s = fetch('reasons_height_adjustment')
    h = $$.height(ReactDOM.findDOMNode(@))
    if h != s.opinion_region_height
      s.opinion_region_height = h
      save s

  transition : -> 
    return if @is_waiting()

    speed = if !@last_proposal_mode then 0 else CRAFTING_TRANSITION_SPEED
    mode = getProposalMode(@props.proposal)


    if @last_proposal_mode != mode 

      if speed > 0      
        # wait for css transitions to complete
        @transitioning = true
        @refs.DecisionBoard.classList.add 'transitioning'

        _.delay => 
          if !@dismounting
            @transitioning = false
            @refs.DecisionBoard.classList.remove 'transitioning'

            @update_reasons_height()
        , speed + 200

      else if !@transitioning
        @update_reasons_height()
            
      @last_proposal_mode = mode



points_for_proposal = (proposal) ->
  fetch("/page/#{proposal.slug}").points or []

stored_points_order = {}
buildPointsList = (proposal, valence, sort_field, filter_included, show_all_points) ->
  return [] if !proposal.slug
  sort_field = sort_field or 'score'
  points = points_for_proposal(proposal)
  opinions = fetch(proposal).opinions


  if !show_all_points
    filtered = true
    opinions = get_opinions_for_proposal opinions, proposal

  if running_timelapse_simulation?
    opinions = (o for o in opinions when passes_running_timelapse_simulation(o.created_at or o.updated_at))
  


  points = (pnt for pnt in points when pnt.is_pro == (valence == 'pros') )



  included_points = proposal.your_opinion.point_inclusions or []
  if filter_included
    points = (pnt for pnt in points when !_.contains(included_points, pnt.key) )
  else 
    for pnt in included_points
      point = fetch pnt 
      continue if pnt.is_pro != (valence == 'pros')
      if points.indexOf(point) == -1
        points.push point 


  # Filter down to the points included in the selected opinions, if set. 
  opinion_views = fetch('opinion_views')
  if opinion_views.active_views.single_opinion_selected
    opinions = [opinion_views.active_views.single_opinion_selected.opinion] 
    filtered = true
  else if opinion_views.active_views.region_selected || (key for key,view of opinion_views.active_views when view.view_type == 'filter' && key != 'just_you').length > 0
    {weights, salience, groups} = compose_opinion_views opinions, proposal
    opinions = (o for o in opinions when salience[o.user.key or o.user] == 1)
    filtered = true


  # order points by resonance to users in view.    
  point_inclusions_per_point = {} # map of points to including users
  _.each opinions, (opinion_key) =>
    opinion = fetch(opinion_key)
    if opinion.point_inclusions
      for point in opinion.point_inclusions
        point_inclusions_per_point[point] ||= 0
        point_inclusions_per_point[point] += 1

  # try enforce k=2-anonymity for hidden points
  # if opinions.length < 2
  #   for point,inclusions of point_inclusions_per_point
  #     if fetch(point).hide_name
  #       delete point_inclusions_per_point[point]

  # really ugly, but if we're hovering over point includers, turning on the point includer filter, 
  # the points will automatically re-sort, causing flickering, unless we some how undo the auto 
  # sorting caused by the point includer filter
  active_views = _.without Object.keys(opinion_views.active_views), 'point_includers'
  sort_key = JSON.stringify {proposal:proposal.key, valence, sort_field, filter_included, show_all_points, views: active_views, pnts: (pnt.key for pnt in points)}
  if sort_key of stored_points_order && opinion_views.active_views.point_includers
    points = stored_points_order[sort_key]
  else 
    points = (pnt for pnt in points when (pnt.key of point_inclusions_per_point) || (TABLET_SIZE() && pnt.key in included_points))

    # Sort points based on resonance with selected users, or custom sort_field
    sort = (pnt) ->
      if filtered || running_timelapse_simulation?
        -point_inclusions_per_point[pnt.key] 
      else 
        -pnt[sort_field]


    points = _.sortBy points, sort
    stored_points_order[sort_key] = points

  (pnt.key for pnt in points)


window.PointsList = ReactiveComponent
  displayName: 'PointsList'

  render: -> 
    points = (fetch(pnt) for pnt in @props.points)

    your_points = fetch @props.reasons_key

    proposal = fetch @props.proposal

    mode = getProposalMode(proposal)


    if @props.points_editable && !your_points.editing_points
      _.extend your_points,
        editing_points : []
        adding_new_point : false
      save your_points

    if @props.rendered_as == 'community_point'
      header_prefix = if mode == 'results' then 'top' else "other"
      header_style = 
        width: "var(--POINT_WIDTH)"
        fontSize: "27px"
        fontWeight: 400 
        position: 'relative'
        left: if @props.valence == 'cons' then -20 else 20
          # Mike: I wanted the headers to be centered over the ENTIRE
          # points including avatars, not just bubbles.  But the
          # avatars are sticking out on their own, so I simulated
          # a centered look with these -20px and +20px offsets
      wrapper = @drawCommunityPoints
    else
      header_prefix = 'your' 
      header_style = 
        fontWeight: 700
        color: focus_color()
        width: "var(--POINT_WIDTH)"
        fontSize: "27px"
      wrapper = @drawYourPoints


    get_heading = (valence) => 
      point_labels = customization("point_labels", proposal)


      heading = point_labels["#{header_prefix}_header"]


      plural_point = get_point_label valence, proposal

      heading_t = translator
                    id: "point_labels.header_#{header_prefix}.#{heading}"
                    key: if point_labels.translate then "/translations" else "/translations/#{fetch('/subdomain').name}"
                    arguments: capitalize(plural_point)
                    heading

      heading_t

    heading = get_heading(@props.valence)
    other_heading = get_heading(if @props.valence == 'pros' then 'cons' else 'pros')
    # Calculate the other header height so that if they break differently,
    # at least they'll have same height
    header_height = Math.max heightWhenRendered(heading,       header_style), \
                             heightWhenRendered(other_heading, header_style)

    HEADING = if @props.rendered_as == 'community_point' then H3 else H4 

    wrapper [


      HEADING 
        key: 'point_list_heading'
        id: @local.key.replace(/\//g,'-')
        className: 'points_heading_label'
        style: _.extend header_style,
          textAlign: 'center'
          marginBottom: 18
          marginTop: 7
          height: header_height
        heading


      UL 
        key: 'points_list'
        'aria-labelledby': @local.key.replace(/\//g,'-')
        if points.length > 0 || @props.rendered_as == 'decision_board_point'
          for point in points
            continue if !passes_running_timelapse_simulation(point.created_at)

            if @props.points_editable && \
               point.key in your_points.editing_points # && !browser.is_mobile
              EditPoint 
                key: point.key
                point: point.key
                proposal: @props.proposal
                fresh: false
                valence: @props.valence
                your_points_key: @props.reasons_key
            else
              Point
                key: point.key
                point: point.key
                rendered_as: @props.rendered_as
                your_points_key: @props.reasons_key
                enable_dragging: @props.points_draggable

        else if points.length == 0 && @props.rendered_as == 'community_point' && mode == "results"
          opinion_views = fetch 'opinion_views'
          none_given = opinion_views.active_views.single_opinion_selected || opinion_views.active_views.region_selected  

          DIV 
            className: 'empty-list-callout'
            style: 
              fontStyle: 'italic'
              textAlign: 'center'
              color: '#777'
              marginLeft: -20

            if none_given
              "No #{get_point_label(@props.valence.substring(0, @props.valence.length - 1) + 's', proposal)} given"

            else               
              "Be the first to add a #{get_point_label(@props.valence.substring(0, @props.valence.length - 1), proposal)}"


      if @props.drop_target && permit('create point', proposal) > 0
        @drawDropTarget()

      if @props.points_editable && permit('create point', proposal) > 0 
        @drawAddNewPoint()
      ] 


  columnStandsOut: -> 
    your_points = fetch @props.reasons_key

    contains_selection = get_selected_point() && \
                         fetch(get_selected_point()).is_pro == (@props.valence == 'pros')
    is_editing = @props.points_editable && \
                 (your_points.editing_points.length > 0 || your_points.adding_new_point)

    contains_selection || is_editing


  drawCommunityPoints: (children) -> 
    proposal = fetch @props.proposal 

    mode = getProposalMode(proposal)


    if mode == 'crafting'
      x_pos = if @props.valence == 'cons' 
                "calc( -1 * var(--DECISION_BOARD_WIDTH) / 2 )"
              else 
                "calc( var(--DECISION_BOARD_WIDTH) / 2  )"
    else
      x_pos = 0



    # TODO: The minheight below is not a principled or complete solution to two
    #       sizing issues: 
    #           1) resizing the reasons region when the height of the decision board 
    #              (which is absolutely positioned) grows taller the wing points
    #           2) when filtering the points on result page to a group of opinions 
    #              with few inclusions, the document height can jarringly fluctuate

    SECTION
      key: 'community_points'
      className: "point_list points_by_community #{@props.valence}_by_community"
      style: _.defaults (@props.style or {}),
        minHeight: (if points_for_proposal(proposal).length > 4 && mode == 'crafting' then window.innerHeight else 100)
        zIndex: if @columnStandsOut() then 6 else 1
        width: "var(--POINT_WIDTH)"

        transition: "transform #{CRAFTING_TRANSITION_SPEED}ms, width #{CRAFTING_TRANSITION_SPEED}ms"
        transform: "translate(#{x_pos}, 0)"
      if mode == 'crafting' && !TABLET_SIZE()

        [A
          key: 'skip to'
          className: 'hidden'
          href: "##{@props.valence}_on_decision_board"
          'data-nojax': true
          onClick: (e) => 
            e.stopPropagation()
            document.activeElement?.blur()
            document.querySelector("[name='#{@props.valence}_on_decision_board']").focus()

          "Skip to Your points."
        A key: 'anchor', name: "#{@props.valence}_by_community"]

      children


  drawYourPoints: (children) -> 
      
    SECTION 
      className: "point_list points_on_decision_board #{@props.valence}_on_decision_board"
      style: _.defaults (@props.style or {}),
        display: 'inline-block'
        verticalAlign: 'top'        
        width: "var(--POINT_WIDTH)"
        marginTop: 28
        position: 'relative'
        zIndex: if @columnStandsOut() then 6 else 1        
        float: if @props.valence == 'pros' then 'right' else 'left'    
      A name: "#{@props.valence}_on_decision_board"
      children

  drawAddNewPoint: -> 
    proposal = fetch @props.proposal
    your_points = fetch @props.reasons_key
    can_add_new_point = permit 'create point', proposal

    opinion_views = fetch 'opinion_views'
    hist_selection = opinion_views.active_views.single_opinion_selected || opinion_views.active_views.region_selected


    if can_add_new_point != Permission.INSUFFICIENT_PRIVILEGES && !hist_selection
      if !your_points.adding_new_point
        DIV 
          key: 'draw add new point'

          DIV 
            onClick: => 
              if can_add_new_point == Permission.NOT_LOGGED_IN
                reset_key 'auth', 
                  form: 'create account'
                  goal: 'To access this forum, please introduce yourself below.'

              else if can_add_new_point == Permission.UNVERIFIED_EMAIL
                reset_key 'auth', 
                  form: 'verify email'
                  goal: 'To participate, please demonstrate you control this email.'

                save auth
                current_user.trying_to = 'send_verification_token'
                save current_user

              else
                your_points.adding_new_point = true
                save your_points

              writeToLog {what: 'click new point'}

            if @props.rendered_as == 'decision_board_point'
              @drawAddNewPointInDecisionBoard()
            else 
              @drawAddNewPointInCommunityCol()

          if @props.rendered_as == 'decision_board_point'

            if @props.valence == 'pros' 
              noun = get_point_label 'pro', proposal 
            else 
              noun = get_point_label 'con', proposal 

            noun = capitalize noun   

            A
              className: 'hidden'
              href: "##{@props.valence}_by_community"
              'data-nojax': true
              onClick: (e) => 
                e.stopPropagation()
                document.activeElement?.blur()
                document.querySelector("[name='#{@props.valence}_by_community']").focus()

              "Skip to #{noun} points by others to vote on important ones."
 
      else # if !browser.is_mobile
        EditPoint
          key: "new_point_#{@props.valence}"
          proposal: @props.proposal
          fresh: true
          valence: @props.valence
          your_points_key: @props.reasons_key

  drawAddNewPointInCommunityCol: ->
    proposal = fetch @props.proposal
    if @props.valence == 'pros' 
      point_label = get_point_label 'pro', proposal 
    else 
      point_label = get_point_label 'con', proposal 

    button_text = translator 
                    id: "engage.add_a_point"
                    pro_or_con: point_label 
                    "Add a new {pro_or_con}"

    DIV 
      id: "add-point-#{@props.valence}"
      className: 'give_a_point'
      style: 
        cursor: 'pointer'
        marginTop: 20


      @drawGhostedPoint
        text: button_text
        is_left: @props.valence == 'cons'
        style: {}
        text_style:
          #color: focus_color()
          textDecoration: 'underline'
          fontSize: if browser.is_mobile then 16



  drawAddNewPointInDecisionBoard: -> 
    proposal = fetch @props.proposal
    your_points = fetch @props.reasons_key

    if @props.valence == 'pros' 
      point_label = get_point_label 'pro', proposal 
    else 
      point_label = get_point_label 'con', proposal 


    DIV 
      className: "point-in-decision-board #{if @props.drop_target then 'with-drop-target' else ''}"
      style: 
        textAlign: 'center'
        marginTop: '1em'
        marginLeft: 0 #if @props.drop_target then 20 else 9
        fontSize: POINT_FONT_SIZE()

      if @props.drop_target

        STYLE 
          dangerouslySetInnerHTML: __html: """
            .point-in-decision-board.with-drop-target .write_#{@props.valence}::before {
              content: "#{t('or', 'or')}";
              position: absolute;
              left: -25px;
              top: 5px;
              font-weight: #{if browser.high_density_display then 300 else 400};
              color: black;
            }
          """


      BUTTON 
        className: "write_#{@props.valence} btn"
        style: 
          marginLeft: 8
          backgroundColor: focus_color()
          position: 'relative'

        TRANSLATE 
          id: "engage.add_a_point"
          pro_or_con: point_label 
          "Add a new {pro_or_con}" 

  drawDropTarget: -> 
    proposal = fetch @props.proposal
    left_or_right = if @props.valence == 'pros' then 'right' else 'left'

    if @props.valence == 'pros' 
      point_label = get_point_label 'pro', proposal 
    else 
      point_label = get_point_label 'con', proposal 

    drop_target_text = TRANSLATE 
                         id: "engage.drag_point.#{left_or_right}"
                         pro_or_con: point_label 
                         left_or_right: left_or_right
                         "Drag a {pro_or_con} from the #{left_or_right}"


    local_proposal = fetch shared_local_key(proposal)

    DIV 
      key: 'drop-target'
      'aria-hidden': true
      style: 
        marginLeft: if @props.valence == 'cons' then 24 else 0
        marginRight: if @props.valence == 'pros' then 24 else 0
        position: 'relative'
        left: if @props.valence == 'cons' then -18 else 18

      @drawGhostedPoint
        text: drop_target_text
        is_left: @props.valence == 'cons'
        style: 
          #padding: "0 #{if @props.valence == 'pros' then '24px' else '0px'} .25em #{if @props.valence == 'cons' then '24px' else '0px'}"        
          opacity: if local_proposal.has_focus == 'edit point' then .1
        text_style: {}


  drawGhostedPoint: (props) ->   
    proposal = fetch @props.proposal  
    text_style = props.text_style or {}
    style = props.style or {}

    text = props.text
    is_left = props.is_left

    padding_x = 18
    padding_y = 12
    stroke_width = 1

    width_calc = "calc( 100% - #{2 * stroke_width}px )"
    text_height = heightWhenRendered(text, {fontSize: "#{POINT_FONT_SIZE()}px", width: width_calc})

    h = Math.max text_height + 2 * padding_y, 85
    s_w = 8
    s_h = 6

    mouth_style = 
      top: 8
      position: 'absolute'
    
    if is_left
      mouth_style['transform'] = 'rotate(270deg) scaleX(-1)'
      mouth_style['left'] = -POINT_MOUTH_WIDTH + stroke_width + 1
    else 
      mouth_style['transform'] = 'rotate(90deg)'
      mouth_style['right'] = -POINT_MOUTH_WIDTH  + stroke_width + 2

    local_proposal = fetch shared_local_key(proposal)

    DIV
      style: _.defaults style, 
        position: 'relative'
        opacity: if local_proposal.has_focus == 'edit point' then .1

      SVG 
        width: "100%"
        height: h
        

        DEFS null,
          PATTERN 
            id: "drop-stripes-#{is_left}-#{s_w}-#{s_h}"
            width: s_w
            height: s_h 
            patternUnits: "userSpaceOnUse"

            RECT 
              key: 'rect'
              width: '100%'
              height: '100%'
              fill: 'white'

            do => 
              if is_left
                cross_hatch = [ 
                  [-s_w/2,    0, s_w,   1.5 * s_h], 
                  [0,    -s_h/2,   1.5 * s_w, s_h]]
              else 
                cross_hatch = [ 
                  [1.5 * s_w,    0, 0,   1.5 * s_h], 
                  [s_w,    -s_h/2,   -s_w/2, s_h]]                  

              for [x1, y1, x2, y2], idx in cross_hatch

                LINE 
                  key: idx
                  x1: x1
                  y1: y1
                  x2: x2 
                  y2: y2 
                  stroke: focus_color()
                  strokeWidth: 1
                  strokeOpacity: .2

        RECT
          width: "99%" #width_calc
          height: h - 2 * stroke_width
          x: stroke_width
          y: stroke_width
          rx: 16
          ry: 16
          fill: "url(#drop-stripes-#{is_left}-#{s_w}-#{s_h})"
          stroke: focus_color()
          strokeWidth: stroke_width
          strokeDasharray: '4, 3'

      SPAN 
        style: _.defaults {}, text_style, 
          fontSize: POINT_FONT_SIZE()
          position: 'absolute'
          top: padding_y
          left: padding_x #+ if is_left then 24 else 0
          width: "calc(100% - 2 * #{padding_x}px)"
          
        text



      Bubblemouth 
        apex_xfrac: 0
        width: POINT_MOUTH_WIDTH
        height: POINT_MOUTH_WIDTH
        fill: '#F9FBFD'  #TODO: somehow make this focus_color() color mixed with white @ .2 opacity
        stroke: focus_color()
        stroke_width: 6
        dash_array: '24, 18'
        style: mouth_style







####
# GroupSelectionRegion
#
# Draws a border around the selected opinion(s)
# Shows a bubble mouth for selected opinions or 
# a user name + avatar display if we've selected
# an individual opinion.
GroupSelectionRegion = ReactiveComponent
  displayName: 'GroupSelectionRegion'

  render : -> 

    opinion_views = fetch 'opinion_views'
    single_opinion_selected = opinion_views.active_views.single_opinion_selected
    region_selected = opinion_views.active_views.region_selected
    has_histogram_focus = single_opinion_selected || region_selected
    return SPAN null if !has_histogram_focus


    # draw a bubble mouth
    w = 36; h = 24

    slidergram_width = ITEM_OPINION_WIDTH() * (if !TABLET_SIZE() then 2 else 1)
    wrapper_padding = 300
    wrapper_width = slidergram_width + wrapper_padding

    margin = wrapper_width - slidergram_width
    stance = (region_selected or single_opinion_selected).opinion_value

    if !region_selected
      histocache = last_histogram_position[@props.proposal]
      return SPAN null if !histocache
      avatar_height = 2 * histocache.positions[single_opinion_selected.user][2]
      # stance = (histocache.positions[single_opinion_selected.user][0] + avatar_height / 2) / slidergram_width

    left = get_opinion_x_pos_projection
      slider_val: stance
      from_width: slidergram_width
      to_width: slidergram_width
      x_min: 0
      x_max: 0

    left += wrapper_padding / 2


    DIV 
      style: 
        width: wrapper_width
        border: if !PHONE_SIZE() then "3px solid #{if get_selected_point() then '#eee' else focus_color() }"
        height: '100%'
        position: 'absolute'
        borderRadius: 32
        left: "calc(50% - #{wrapper_width / 2}px)"
        top: 4 #18


      if !PHONE_SIZE()
        DIV 
          style: cssTriangle 'top', \
                             (if get_selected_point() then '#eee' else focus_color()), \
                             w, h,               
                                position: 'relative'
                                top: -26
                                left: left - w / 2

          DIV
            style: cssTriangle 'top', 'white', w - 1, h - 1,
              position: 'relative'
              left: -(w - 2) / 2
              top: 6


      if single_opinion_selected
        # display a name for the selected opinion

        name_style = 
          fontSize: "#{if PHONE_SIZE() then 18 else 30}px"
          fontWeight: 600
          whiteSpace: 'nowrap'

        user = fetch(fetch(single_opinion_selected.opinion).user)
        name = user.name or anonymous_label()
        title = "#{name}'#{if name[name.length - 1] != 's' then 's' else ''} Opinion"
        name_width = widthWhenRendered(title, name_style)

        DIV
          style: _.extend name_style,
            position: 'absolute'
            top: -(avatar_height + 172)
            color: focus_color()
            left: "min(#{wrapper_width - name_width}px, max(0px, calc(#{left}px - #{name_width / 2}px)))" #Math.min(wrapper_width - name_width - 10, Math.max(0, left - name_width / 2))
          title 
  