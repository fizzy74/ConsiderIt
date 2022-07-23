require "./comment"


##
# Point
# A single point in a list. 
window.Point = ReactiveComponent
  displayName: 'Point'

  render : ->
    point = @data()

    is_selected = get_selected_point() == @props.key

    current_user = fetch('/current_user')


    renderIncluders = (draw_all_includers) =>

      if @data().includers

        if draw_all_includers
          includers = @buildIncluders()
        else 
          includers = [point.user]

        s = #includers_style
          rows: 8
          dx: 2
          dy: 5
          col_gap: 8

        if includers.length == 0
          includers = [point.user]

        # Now we'll go through the list from back to front
        i = includers.length

        DIV null,

          for includer in includers
            i -= 1
            curr_column = Math.floor(i / s.rows)
            side_offset = curr_column * s.col_gap + i * s.dx
            top_offset = (i % s.rows) * s.dy 
            left_right = if @data().is_pro then 'left' else 'right'
            style = 
              top: top_offset
              position: 'absolute'

            style[left_right] = side_offset

            # Finally draw the guys
            Avatar
              key: includer
              className: "point_includer_avatar"
              style: style
              set_bg_color: true
              anonymous: point.user == includer && point.hide_name



    point_content_style = 
      width: POINT_WIDTH() #+ 6
      borderWidth: 3
      borderStyle: 'solid'
      borderColor: 'transparent'
      top: -3
      position: 'relative'
      zIndex: 1
      outline: 'none'

    if is_selected
      _.extend point_content_style,
        borderColor: focus_color()
        backgroundColor: 'white'

    else if @local.has_focus
      _.extend point_content_style,
        borderColor: '#999'
        backgroundColor: 'white'

    if @props.rendered_as == 'decision_board_point'
      _.extend point_content_style,
        padding: 8
        borderRadius: 8
        top: point_content_style.top - 8
        left: -11
        #width: point_content_style.width + 16

    else if @props.rendered_as == 'community_point'
      _.extend point_content_style,
        padding: 8
        borderRadius: if TWO_COL() then "16px 16px 0 0" else 16
        top: point_content_style.top - 8
        #left: point_content_style.left - 8
        #width: point_content_style.width + 16


    expand_to_see_details = !!point.text

    point_style = 
      position: 'relative'
      listStyle: 'none outside none'


    if @props.rendered_as == 'decision_board_point'
      _.extend point_style, 
        marginLeft: 9
        padding: '0 18px 0 18px'
    else if @props.rendered_as == 'community_point'
      point_style.marginBottom = '0.5em'



    includers_style = 
      position: 'absolute'
      height: 25
      width: 25
      top: 0
    left_or_right = if @data().is_pro && @props.rendered_as != 'decision_board_point'
                      'right' 
                    else 
                      'left'
    ioffset = -50
    includers_style[left_or_right] = ioffset

    draw_all_includers = @props.rendered_as == 'community_point' || TWO_COL()

    if expand_to_see_details && !is_selected
      append = SPAN 
        key: 1
        style:
          fontSize: 10
          color: '#888'
        " (#{translator({id: "engage.read_more"}, "read more")})"

    else 
      append = null

    LI
      key: "point-#{point.id}"
      'data-id': @props.key
      className: "point #{@props.rendered_as} #{if point.is_pro then 'pro' else 'con'} #{if customization('disable_comments') && !expand_to_see_details then 'commenting-disabled' else ''}"
      onClick: @selectPoint
      onTouchEnd: @selectPoint
      onKeyDown: (e) =>
        if (is_selected && e.which == 27) || e.which == 13 || e.which == 32
          @selectPoint(e)
          e.preventDefault()
      style: point_style

      if @props.rendered_as == 'decision_board_point'
        DIV 
          style: 
            position: 'absolute'
            left: 0
            top: -2

          if @data().is_pro then '•' else '•'

      DIV 
        className:'point_content'
        style : point_content_style
        tabIndex: 0
        onBlur: (e) => @local.has_focus = false; save(@local)
        onFocus: (e) => @local.has_focus = true; save(@local)

        if @props.rendered_as != 'decision_board_point'

          side = if point.is_pro then 'right' else 'left'
          mouth_style = 
            top: 8
            position: 'absolute'

          mouth_style[side] = -POINT_MOUTH_WIDTH + \
            if is_selected || @local.has_focus then 3 else 1
          
          if !point.is_pro
            mouth_style['transform'] = 'rotate(270deg) scaleX(-1)'
          else 
            mouth_style['transform'] = 'rotate(90deg)'

          DIV 
            'role': 'presentation'
            key: 'community_point_mouth'
            style: css.crossbrowserify mouth_style

            Bubblemouth 
              apex_xfrac: 0
              width: POINT_MOUTH_WIDTH
              height: POINT_MOUTH_WIDTH
              fill: considerit_gray
              stroke: if is_selected then focus_color() else if @local.has_focus then '#888' else 'transparent'
              stroke_width: if is_selected || @local.has_focus then 20 else 0
              box_shadow:   
                dx: 3
                dy: 0
                stdDeviation: 2
                opacity: .5

        DIV 
          style: 
            wordWrap: 'break-word'
            fontSize: POINT_FONT_SIZE()

          DIV 
            className: 'point_nutshell'

            splitParagraphs point.nutshell, append



          DIV 
            id: "point-aria-interaction-#{point.id}"
            className: 'hidden'

            translator
              id: "engage.point_explanation"
              author: if point.hide_name then anonymous_label() else fetch(point.user).name
              num_inclusions: @data().includers.length
              comment_count: point.comment_count
              """By {author}. 
                 { num_inclusions, plural, =0 {} one {Important to one person.} other {Important to # people.} } 
                 {comment_count, plural, =0 {} one {Has received one comment.} other {Has received # comments.} }
                 Press ENTER or SPACE for details or discussion."""

          DIV 
            'aria-hidden': true
            className: "point_details" + \
                       if is_selected
                         ''
                       else 
                         '_tease'

            style: 
              wordWrap: 'break-word'
              marginTop: '0.5em'
              fontSize: POINT_FONT_SIZE()
              fontWeight: if browser.high_density_display && !browser.is_mobile then 300 else 400              
              

            DIV 
              style: 
                fontSize: 12
                color: '#666'

              if !screencasting() && !embedded_demo() && fetch('/subdomain').name != 'galacticfederation'
                [
                  prettyDate(point.created_at)
                  SPAN style: paddingLeft: 8
                ]

              if !customization('disable_comments')
                SPAN 
                  key: 2 
                  style: {whiteSpace: 'nowrap'}

                  A 
                    className: 'select_point'

                    translator
                      id: 'engage.link_to_comments'
                      comment_count: point.comment_count 
                      "{comment_count, plural, one {# comment} other {# comments}}"



        if current_user.user == point.user
          DIV null,
            if permit('update point', point) > 0 && 
                (@props.rendered_as == 'decision_board_point' || TWO_COL())
              BUTTON
                style:
                  fontSize: if browser.is_mobile then 24 else 14
                  color: focus_color()
                  padding: '3px 12px 3px 0'
                  backgroundColor: 'transparent'
                  border: 'none'

                onTouchEnd: (e) -> e.stopPropagation()
                onClick: ((e) =>
                  e.stopPropagation()
                  points = fetch(@props.your_points_key)
                  points.editing_points.push(@props.key)
                  save(points))
                translator 'engage.edit_button', 'edit'

            if permit('delete point', point) > 0 && 
                (@props.rendered_as == 'decision_board_point' || TWO_COL())
              BUTTON
                'data-action': 'delete-point'
                style:
                  fontSize: if browser.is_mobile then 24 else 14
                  color: focus_color()
                  padding: '3px 8px'
                  backgroundColor: 'transparent'
                  border: 'none'
                onTouchEnd: (e) -> e.stopPropagation()       
                onClick: (e) =>
                  e.stopPropagation()
                  if confirm('Delete this point forever?')
                    destroy @props.key
                translator 'engage.delete_button', 'delete'

      if @props.rendered_as != 'decision_board_point' 
        DIV 
          'aria-hidden': true
          className:'includers'
          onMouseEnter: @highlightIncluders
          onMouseLeave: @unHighlightIncluders
          style: includers_style
            
          renderIncluders(draw_all_includers)



      if TWO_COL() || (!TWO_COL() && @props.enable_dragging)
        your_opinion = @proposal.your_opinion
        if your_opinion.key 
          fetch your_opinion
        if your_opinion?.published
          can_opine = permit 'update opinion', @proposal, your_opinion
        else
          can_opine = permit 'publish opinion', @proposal

        included = @included()
        includePoint = (e) => 
          e.stopPropagation()
          e.preventDefault()

          return unless e.type != 'click' || \
                        (!browser.is_android_browser && e.type == 'click')
          if included
            @remove()
          else 
            @include()

        if !TWO_COL() && @props.enable_dragging
          right = (included && point.is_pro) || (!included && !point.is_pro)
          if right 
            sty = 
              right: if !@local.focused_include then 20 else if included then -20 else -40
          else 
            sty = 
              left: if !@local.focused_include then 20 else if included then -20 else -40

          BUTTON
            'aria-label': if included 
                            translator 'engage.uninclude_explanation', 'Mark this point as unimportant and move to next point' 
                          else 
                            translator 'engage.include_explanation', 'Mark this point as important and move to next point'
            style: _.extend sty, 
              position: 'absolute'
              top: 20
              opacity: if !@local.focused_include then 0
              padding: 0
              backgroundColor: 'transparent'
              border: 'none'              
              display: if get_selected_point() then 'none'
            onFocus: (e) => @local.focused_include = true; save @local
            onBlur: (e) => @local.focused_include = false; save @local
            onTouchEnd: includePoint
            onClick: includePoint
            onKeyDown: (e) => 
              if e.which == 13 || e.which == 32

                next = $(e.target).closest('.point').next().find('.point_content')
                includePoint(e)
                valence = if @data().is_pro then 'pros' else 'cons'

                next.focus()
                e.preventDefault()

            I 
              style: 
                fontSize: if included then 25 else 40
                color: focus_color()
              className: "fa fa-long-arrow-#{if !right then 'left' else 'right'}"

        else
          BUTTON 
            style: 
              border: "1px solid #{ if included || @local.hover_important then focus_color() else '#414141'}"
              borderTopColor: if included then focus_color() else 'transparent'
              color: if included then 'white' else if @local.hover_important then focus_color() else "#414141"
              position: 'relative'
              top: -13
              padding: '8px 5px'
              textAlign: 'center'
              borderRadius: '0 0 16px 16px'
              cursor: 'pointer'
              backgroundColor: if included then focus_color() else 'white'
              fontSize: 18  
              zIndex: 0
              display: if can_opine < 0 then 'none'
              width: '100%'

            onMouseEnter: => 
              @local.hover_important = true
              save @local
            onMouseLeave: => 
              @local.hover_important = false
              save @local

            onTouchEnd: includePoint
            onClick: includePoint

            I
              className: 'fa fa-thumbs-o-up'
              style: 
                display: 'inline-block'
                marginRight: 10

            translator("engage.include_button", "Important point") + "#{if included then '' else '?'}" 


      if is_selected
        Discussion
          key:"/comments/#{point.id}"
          point: point.key
          rendered_as: @props.rendered_as

  componentDidMount : ->    
    @setDraggability()
    @ensureDiscussionIsInViewPort()

  componentDidUpdate : -> 
    @setDraggability()
    @ensureDiscussionIsInViewPort()


  # Hack that fixes a couple problems:
  #   - Scroll to the point when following a link from an email 
  #     notification to a point
  #   - Scroll to new point when scrolled down to bottom of long 
  #     discussion & click a new point below it
  ensureDiscussionIsInViewPort : ->
    is_selected = get_selected_point() == @props.key
    if @local.is_selected != is_selected
      if is_selected
        if browser.is_mobile
          $(@getDOMNode()).moveToTop {scroll: false}
        else
          $(@getDOMNode()).ensureInView {scroll: false}
        
        i = setInterval ->
              if $('#open_point').length > 0 
                $('#open_point').focus()
                clearInterval i
            , 10

      @local.is_selected = is_selected
      save @local

  setDraggability : ->
    # Ability to drag include this point if a community point, 
    # or drag remove for point on decision board
    # also: disable for results page

    $point_content = $(@getDOMNode()).find('.point_content')
    revert = 
      if @props.rendered_as == 'community_point' 
        'invalid' 
      else (valid) =>
        if !valid
          @remove()
        valid

    if $point_content.hasClass "ui-draggable"
      $point_content.draggable(if @props.enable_dragging then 'enable' else 'disable' ) 
    else
      $point_content.draggable
        revert: revert
        disabled: !@props.enable_dragging

  included: -> 
    your_opinion = @proposal.your_opinion
    your_opinion.point_inclusions ?= []
    your_opinion.point_inclusions.indexOf(@props.key) > -1

  remove: -> 

    pnt = fetch @props.key 

    validate_first = pnt.user == fetch('/current_user').user && pnt.includers.length < 2


    if !validate_first || confirm('Are you sure you want to remove your point? It will be gone forever.')

      your_opinion = @proposal.your_opinion
      your_opinion.point_inclusions ?= []
      your_opinion.point_inclusions = _.without your_opinion.point_inclusions, \
                                                @props.key

      your_opinion.key ?= "/new/opinion"
      save(your_opinion)
      window.writeToLog
        what: 'removed point'
        details: 
          point: @props.key
    else 
      $point_content = $(@getDOMNode()).find('.point_content')
      $point_content.css 'left', '-11px'
      $point_content.css 'top', '-11px'

  include: -> 
    your_opinion = @proposal.your_opinion
    your_opinion.key ?= "/new/opinion"

    your_opinion.published = true 
    your_opinion.point_inclusions ?= []
    your_opinion.point_inclusions.push @data().key
    save(your_opinion)

    window.writeToLog
      what: 'included point'
      details: 
        point: @data().key


  selectPoint: (e) ->
    e.stopPropagation()
    point = @data()

    return if !point.text && customization('disable_comments')


    # android browser needs to respond to this via a touch event;
    # all other browsers via click event. iOS fails to select 
    # a point if both touch and click are handled...sigh...
    return unless ( browser.is_mobile && e.type != 'click' ) || \
                  (!browser.is_mobile && e.type == 'click') || \
                  e.type == 'keydown'


    loc = fetch('location')
    if get_selected_point() == @props.key # deselect
      delete loc.query_params.selected
      what = 'deselected a point'

      document.activeElement.blur()
    else
      what = 'selected a point'
      loc.query_params.selected = @props.key

    save loc

    window.writeToLog
      what: what
      details: 
        point: @props.key


  ## ##
  # On hovering over a point, highlight the people who included this 
  # point in the Histogram.
  highlightIncluders : -> 
    point = @data()
    includers = point.includers

    # For point authors who chose not to sign their points, remove them from 
    # the users to highlight. This is particularly important if the author 
    # is the only one who "included" the point. Then it is very eash for 
    # anyone to discover who wrote this point. 
    if point.hide_name
      includers = _.without includers, point.user

    opinion_views = fetch 'opinion_views'
    opinion_views.active_views.point_includers =
      created_by: @props.key 
      point: point.key 
      get_salience: (u, opinion, proposal) ->
        if (u.key or u) in includers 
          1 
        else 
          .1
    save opinion_views


  unHighlightIncluders : -> 
    opinion_views = fetch 'opinion_views'
    if opinion_views.active_views.point_includers
      delete opinion_views.active_views.point_includers
      save opinion_views

  buildIncluders : -> 
    point = @data()

    includers = point.includers

    opinion_views = fetch 'opinion_views'
    {weights, salience, groups} = compose_opinion_views null, @proposal

    includers = (i for i in includers when salience[i] == 1 && weights[i] > 0)

    includers = _.without includers, point.user
    includers.push point.user

    _.uniq includers
        

styles += """

/* war! disabled jquery UI draggable class defined with !important */
.point_content.ui-draggable-disabled {
  cursor: pointer !important; }

.commenting-disabled .point_content.ui-draggable-disabled {
  cursor: auto !important; }


.commenting-disabled .point_details_tease {
  cursor: auto;
}

#{css.grab_cursor('.point_content.ui-draggable')}

.community_point .point_content {
  border-radius: 16px;
  padding: 0.5em 9px;
  background-color: #{considerit_gray};
  box-shadow: #b5b5b5 0 1px 1px 0px;
  min-height: 34px; }

.point_nutshell a { text-decoration: underline; }
.point_details_tease a, .point_details a {
  text-decoration: underline;
  word-break: break-all; }
.point_details a.select_point{
  text-decoration: none;
  font-weight: 400;
}

.point_details {
  display: block; }

.point_details_tease {
  cursor: pointer; }
  .point_details_tease a.select_point {
    text-decoration: none; 
    font-weight: 400;    
    }
    .point_details_tease a.select_point:hover {
      text-decoration: underline; }

.point_details p {
  margin-bottom: 1em; }

.point_details p:last-child {
  margin-bottom: 0; }

.point_includer_avatar {
  width: 22px;
  height: 22px; }

.community_point.con .point_includer_avatar {
  box-shadow: -1px 2px 0 0 #eeeeee; }

.community_point.pro .point_includer_avatar {
  box-shadow: 1px 2px 0 0 #eeeeee; }

.decision_board_point.pro .point_includer_avatar {
  left: -10px; }

"""
