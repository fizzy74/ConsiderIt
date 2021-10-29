class OpinionController < ApplicationController

  def show
    opinion = Opinion.find(params[:id])
    authorize! 'read opinion', opinion
    dirty_key "/opinion/#{params[:id]}"
    render :json => []
  end

  def create
    proposal = Proposal.find(key_id(params['proposal']))
    authorize! 'publish opinion', proposal

    fields = ['proposal', 'stance', 'point_inclusions']
    updates = params.select{|k,v| fields.include? k}.to_h

    # Convert proposal key to id
    updates['proposal_id'] = key_id(updates['proposal'])
    updates.delete('proposal')

    # Convert point_inclusions to ids
    incs = updates['point_inclusions']
    incs = [] if incs.nil? # Damn rails http://guides.rubyonrails.org/security.html#unsafe-query-generation

    incs = incs.map! {|p| key_id(p)}
    updates['point_inclusions'] = incs

    updates['user_id'] = current_user.id 
    
    opinion = Opinion.new updates 
    opinion.update_inclusions incs

    opinion.save 
    opinion.publish()
    write_to_log({
      :what => 'published opinion',
      :where => proposal.slug
    })

    original_id = key_id(params[:key])
    result = opinion.as_json
    result['key'] = "/opinion/#{opinion.id}?original_id=#{original_id}"

    dirty_key "/proposal/#{proposal.id}"
    render :json => [result]

  end
  
  def update
    opinion = Opinion.find key_id(params)
    authorize! 'update opinion', opinion

    fields = ['proposal', 'stance', 'point_inclusions', 'explanation']
    updates = params.select{|k,v| fields.include? k}.to_h

    # Convert proposal key to id
    updates['proposal_id'] = key_id(updates['proposal'])
    updates.delete('proposal')

    # Convert point_inclusions to ids
    incs = updates['point_inclusions']
    incs = [] if incs.nil? # Damn rails http://guides.rubyonrails.org/security.html#unsafe-query-generation

    incs = incs.map! {|p| key_id(p)}
    opinion.update_inclusions incs
    updates['point_inclusions'] = incs

    # Grab the proposal
    proposal = Proposal.find(updates['proposal_id'])
    
    # Update the normal fields
    opinion.update_attributes updates
    opinion.save

    # Update published
    if params['published'] && !opinion.published
      authorize! 'publish opinion', proposal

      opinion.publish()  # This will also publish all the newly-written points

      write_to_log({
        :what => 'published opinion',
        :where => proposal.slug
      })
    elsif params.has_key?('published') && !params['published'] && opinion.published
      opinion.unpublish()
      write_to_log({
        :what => 'unpublished opinion',
        :where => proposal.slug
      })

    end

    dirty_key "/proposal/#{proposal.id}"
    
    dirty_key "/opinion/#{opinion.id}"

    render :json => []

  end

end
