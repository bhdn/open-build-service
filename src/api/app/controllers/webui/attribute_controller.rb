class Webui::AttributeController < Webui::WebuiController
  helper :all
  before_filter :set_container, :only => [:index, :new, :edit]
  before_filter :set_attribute, :only => [:update, :destroy]
  before_filter :set_attribute_by_name, :only => [:edit]

  helper 'webui/project'

  def index
    @attributes = @container.attribs
  end

  def new
    if @package
      @attribute = Attrib.new(package_id: @package.id)
    else
      @attribute = Attrib.new(project_id: @project.id)
    end
  end

  def edit
    if @attribute.attrib_type.value_count and ( @attribute.attrib_type.value_count > @attribute.values.length )
      ( @attribute.attrib_type.value_count - @attribute.values.length ).times do |i|
        @attribute.values.build(attrib: @attribute)
      end
    end
  end

  def create
    @attribute = Attrib.new(attrib_params)
    # check access
    unless User.current.can_create_attribute_in? @attribute.container, namespace: @attribute.namespace, name: @attribute.name
      redirect_to :back, error: "You have no permission to create attribute #{@attribute.fullname}"
      return
    end
    if @attribute.attrib_type.value_count
      @attribute.attrib_type.value_count.times do
        @attribute.values.build(attrib: @attribute)
      end
    end

    if @attribute.save
      if @attribute.values_editable?
        redirect_to edit_attribs_path(:project => @attribute.project.to_s, :package => @attribute.package.to_s, :attribute => @attribute.fullname),
        notice: 'Attribute was successfully created.'
      else
        redirect_to index_attribs_path(:project => @attribute.project.to_s, :package => @attribute.package.to_s),
        notice: 'Attribute was successfully created.'
      end
    else
      redirect_to :back, error: "Saving attribute failed: #{@attribute.errors.full_messages.join(', ')}"
    end
  end

  def update
    # check access
    unless User.current.can_create_attribute_in? @attribute.container, namespace: @attribute.namespace, name: @attribute.name
      redirect_to :back, error: "You have no permission to modify attribute #{@attribute.fullname}"
      return
    end

    if @attribute.update(attrib_params)
      redirect_to edit_attribs_path(:project => @attribute.project.to_s, :package => @attribute.package.to_s, :attribute => @attribute.fullname),
      notice: 'Attribute was successfully updated.'
    else
      redirect_to :back, error: "Updating attribute failed: #{@attribute.errors.full_messages.join(', ')}"
    end
  end

  def destroy
    # check access
    unless User.current.can_create_attribute_in? @attribute.container, namespace: @attribute.namespace, name: @attribute.name
      redirect_to :back, error: "You have no permission to modify attribute #{@attribute.fullname}"
      return
    end

    @attribute.destroy
    redirect_to :back, notice: 'Attribute sucessfully deleted!'
  end

  private

  def set_container
    required_parameters :project
    begin
      @project = Project.get_by_name(params[:project])
    rescue APIException
      flash[:error] = "Project not found: #{params[:project]}"
      redirect_to :controller => 'project', :action => 'list_public' and return
    end
    if params[:package]
      begin
        @package = Package.get_by_project_and_name(params[:project], params[:package], use_source: false)
      rescue APIException
        redirect_to project_show_path(@project.to_s), error: "Package #{params[:package]} not found" and return
      end
      @container = @package
    else
      @container = @project
    end
  end

  def set_attribute_by_name
    logger.debug "Trying to find attribute #{params[:attribute]} on #{@container.to_s}"
    @attribute = Attrib.find_by_container_and_fullname( @container, params[:attribute] )
    unless @attribute
      logger.debug "Did not find attribute #{params[:attribute]} on #{@container.to_s}"
    end
  end

  def set_attribute
    @attribute = Attrib.find(params[:id])
    if @attribute.container.instance_of? Package
      @package = @attribute.container
      @project = @package.project
    elsif @attribute.container.instance_of? Project
      @project = @attribute.container
    end
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def attrib_params
    params.require(:attrib).permit(:attrib_type_id, :project_id, :package_id, values_attributes: [:id, :value, :position, :_destroy], issues_attributes: [:id, :name, :issue_tracker_id, :_destroy])
  end

end
