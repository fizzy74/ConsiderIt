class UserController < ApplicationController
  respond_to :json
  def show
    puts("Show(#{params[:id]})")

    if params[:id] == '-1'
      render :json => {
               'key' => '/user/-1',
               'name' => 'anonymous',
               'avatar_file_name' => nil
             }
      return
    end
    
    user = User.find(params[:id])
    render :json => user.as_json
  end
end
