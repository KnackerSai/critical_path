class TaskController < ApplicationController
  protect_from_forgery

  def update
    task = Task.find(params["id"])
    task.text = params["text"]
    task.start_date = params["start_date"]
    task.duration = params["duration"]
    task.progress = params["progress"]
    task.sortorder = params["sortorder"]
    task.parent = params["parent"]
    task.save

    render :json => {:status => "ok"}
  end

  def add
    task = Task.create :text => params["text"], :start_date=> params["start_date"], :duration => params["duration"],
                       :progress => params["progress"], :sortorder => params["sortorder"], :parent => params["parent"]

    render :json => {:tid => task.id}
  end

  def delete
    Task.find(params["id"]).destroy
    render :json => {:status => "ok"}
  end
end
