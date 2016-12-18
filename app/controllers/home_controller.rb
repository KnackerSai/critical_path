class HomeController < ApplicationController
  def index

  end

  def critical_path
    @es="Early start"
    @ef="Early finish"
    @ls="Late start"
    @lf="Late finish"
    @cr_p="Critical task?"
    @free="Possible days moving"

    @start_date=DateTime.new(4000, 1, 1, 1, 1, 1)
    tasks_sources_count={}
    tasks_targets_count={}

    tree={}
    reverse_tree={}

    start_points=[]
    end_points=[]

    @critical_path=[]
    @critical_duration=0

    @tasks_params={}

    delete_wrong_links

    #init hash with count sources of object
    Task.all.each do |task|
      tasks_sources_count[task.id]=0
      tasks_targets_count[task.id]=0
      if task.start_date < @start_date
        @start_date=task.start_date
      end
    end

    #fill sources hash and tree of tasks
    fill_trees_and_counts(tree,reverse_tree,tasks_targets_count,tasks_sources_count)

    #fill array of start tasks (tasks without sources)
    tasks_sources_count.each do |key,value|
      if value==0
        start_points.push(key)
      end
    end

    tasks_targets_count.each do |key,value|
      if value==0
        end_points.push(key)
      end
    end

    #get critical path
    start_points.each do |start_point|
      path=[]
      duration=0
      result=find_critical_path(start_point,path,duration,tree)
      if result[1] > @critical_duration
        @critical_path=result[0]
        @critical_duration=result[1]
      end
    end

    #init array of tasks params
    Task.all.each do |task|
      @tasks_params[task.id]={@es => 0, @ef => task.duration,
                              @ls => @critical_duration-task.duration, @lf => @critical_duration,
                              @cr_p=>"no", @free => 0}
    end

    #set starts and finishs
    start_points.each do |start_point|
      set_early_params(start_point,tree)
    end

    end_points.each do |end_point|
      set_late_params(end_point,reverse_tree)
    end

    #set dates and color
    Task.all.each do |task|
      if @tasks_params[task.id][@es]==@tasks_params[task.id][@ls]
        @tasks_params[task.id][@cr_p]="CRITICAL"
        task.color="red"
      else
        task.color="green"
      end
      @tasks_params[task.id][@free]=@tasks_params[task.id][@ls]-@tasks_params[task.id][@es]
      task.start_date=@start_date+@tasks_params[task.id][@es].days
      task.save
    end
  end

  def fill_trees_and_counts(tree,reverse_tree,tasks_targets_count,tasks_sources_count)
    Link.all.each do |link|
      #sources count
      if tasks_sources_count.key?(link.target)
        tasks_sources_count[link.target]+=1
      end

      #targets count
      if tasks_targets_count.key?(link.source)
        tasks_targets_count[link.source]+=1
      end

      #tree
      if not tree.key?(link.source)
        tree[link.source]=[link.target]
      else
        tree[link.source].push(link.target)
      end

      #reverse_tree
      if not reverse_tree.key?(link.target)
        reverse_tree[link.target]=[link.source]
      else
        reverse_tree[link.target].push(link.source)
      end
    end
  end

  def set_early_params(start_point,tree)
    if tree.key?(start_point)
      tree[start_point].each do |next_point|
        if @tasks_params[next_point][@es] < @tasks_params[start_point][@ef]
          @tasks_params[next_point][@es]=@tasks_params[start_point][@ef]
          @tasks_params[next_point][@ef]=@tasks_params[next_point][@es]+Task.find(next_point).duration

        end
        set_early_params(next_point,tree)
      end
    end
  end

  def set_late_params(end_point,reverse_tree)
    if reverse_tree.key?(end_point)
      reverse_tree[end_point].each do |prev_point|
        if (@tasks_params[prev_point][@lf]) >= @tasks_params[end_point][@ls]
          @tasks_params[prev_point][@lf]=@tasks_params[end_point][@ls]
          @tasks_params[prev_point][@ls]=@tasks_params[prev_point][@lf]-Task.find(prev_point).duration
        end
        set_late_params(prev_point,reverse_tree)
      end
    end
  end

  def find_critical_path(start_point,path,duration,tree)
    #puts("We are at " + start_point.to_s + ". Our path: " + path.to_s)
    old_path=[]
    path.each do |id|
      old_path.push(id)
    end

    old_path.push(start_point)
    duration+=Task.find(start_point).duration

    if tree.key?(start_point)
      max_duration=-1
      max_path=[]

      tree[start_point].each do |next_point|
        #puts("We are still at " + start_point.to_s + ". We now will go to " + next_point.to_s)
        result=find_critical_path(next_point,old_path,duration,tree)
        #puts("We returned to " + start_point.to_s + ". Result[0]: " +result[0].to_s + ", Resilt[1]: " + result[1].to_s)

        if result[1] > max_duration
          max_duration=result[1]
          max_path=result[0]
        end
      end

      return [max_path,max_duration]
    else
      #puts("We are at " + start_point.to_s + ", this is end. Our path: " + old_path.to_s)
      return [old_path,duration]
    end
  end

  def delete_wrong_links
    links={}
    Link.all.each do |link|
      if not (Task.exists?(link.source) or Task.exists?(link.target))
        link.delete
      elsif links.key?([link.source,link.target])
        link.delete
      else
        links[[link.source,link.target]]=0
      end
    end
  end

  def data
    tasks = Task.all
    links = Link.all

    render :json=>{
        :data => tasks.map{|task|{
            :id => task.id,
            :text => task.text,
            :start_date => task.start_date.to_formatted_s(:db),
            :duration => task.duration,
            :progress => task.progress,
            :sortorder => task.sortorder,
            :parent => task.parent,
            :color => task.color
        }},
        :links => links.map{|link|{
            :id => link.id,
            :source => link.source,
            :target => link.target,
            :type => link.link_type
        }}
    }
  end
end
