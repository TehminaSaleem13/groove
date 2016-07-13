class DelayedJobsController < ApplicationController
	before_filter :groovepacker_authorize!
	prepend_before_filter :initialize_result_obj

	def index
		delayed_jobs = params[:search].present? ? Delayed::Job.where("(handler like ? or queue like ?) and updated_at > ?", "%#{params[:search]}%", "%#{params[:search]}%", Date.today - 2 ) : Delayed::Job.where("updated_at > ?", Date.today - 2)
		@result["total_count"] = delayed_jobs.count
		@result['delayed_jobs'] = delayed_jobs.order(params["sort"] + " " + params["order"]).limit(params["limit"]).offset(params["offset"]).as_json
		@result['delayed_jobs'].each_with_index do |delayed_job, index|
			get_delayed_time(delayed_job, index)	
		end 
	render json: @result 
	end

	def get_delayed_time(delayed_job, index)
		if delayed_job["locked_at"].present? && delayed_job["failed_at"].blank? && delayed_job["attempts"] != 5
			time_count = {}
			delayed_time = Time.now.utc - delayed_job["locked_at"]
			time_count["delayed_job_time"] = Time.at(delayed_time).utc.strftime('%Hh %Mm %Ss')
			delayed_job = delayed_job.merge(time_count)
			@result['delayed_jobs'][index] = delayed_job
		end	
	end

	def destroy
		delayed_job_id = params['delayed_job']['_json']
		if delayed_job_id.present?
			Delayed::Job.destroy(delayed_job_id)
			@result['messages'] = "Delayed Job deleted"
	end
		render json: @result 
	end

	def update
		if params["_json"][0]["select_all"]
		 	Delayed::Job.destroy_all
		else
			params["_json"].each_with_index do |delayed_job, index|
				Delayed::Job.destroy(delayed_job["id"]) if index != 0
			end
		end
		@result['messages'] = "Delayed Jobs are deleted"
		render json: @result
	end

	def reset
		if params["id"].present? && params["attempts"] != 5
			job = Delayed::Job.find(params["id"])
			job.attempts = 0
			job.last_error = nil
			job.run_at = Time.now - 1.day
			job.locked_at = nil
			job.locked_by = nil
			job.failed_at = nil
			job.save!
			job.reload
			@result['messages'] = "Delayed Job restarted"
		else
			@result['status'] = false
			@result['messages'] = "Delayed Job can not restart"
		end 
		render json: @result
	end

	private
		def initialize_result_obj
			@result = { 'status' => true, 'messages' => [], 'error_messages' => [], 'success_messages' => [], 'notice_messages' => [] }
		end
end
