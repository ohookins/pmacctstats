class UsageEntriesController < ApplicationController
  # GET /usage_entries
  # GET /usage_entries.xml
  def index
    @usage_entries = UsageEntry.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @usage_entries }
    end
  end

  # GET /usage_entries/1
  # GET /usage_entries/1.xml
  def show
    @usage_entry = UsageEntry.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @usage_entry }
    end
  end

  # GET /usage_entries/new
  # GET /usage_entries/new.xml
  def new
    @usage_entry = UsageEntry.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @usage_entry }
    end
  end

  # GET /usage_entries/1/edit
  def edit
    @usage_entry = UsageEntry.find(params[:id])
  end

  # POST /usage_entries
  # POST /usage_entries.xml
  def create
    @usage_entry = UsageEntry.new(params[:usage_entry])

    respond_to do |format|
      if @usage_entry.save
        flash[:notice] = 'UsageEntry was successfully created.'
        format.html { redirect_to(@usage_entry) }
        format.xml  { render :xml => @usage_entry, :status => :created, :location => @usage_entry }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @usage_entry.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /usage_entries/1
  # PUT /usage_entries/1.xml
  def update
    @usage_entry = UsageEntry.find(params[:id])

    respond_to do |format|
      if @usage_entry.update_attributes(params[:usage_entry])
        flash[:notice] = 'UsageEntry was successfully updated.'
        format.html { redirect_to(@usage_entry) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @usage_entry.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /usage_entries/1
  # DELETE /usage_entries/1.xml
  def destroy
    @usage_entry = UsageEntry.find(params[:id])
    @usage_entry.destroy

    respond_to do |format|
      format.html { redirect_to(usage_entries_url) }
      format.xml  { head :ok }
    end
  end
end
