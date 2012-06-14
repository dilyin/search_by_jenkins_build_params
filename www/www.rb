require 'rubygems'
require 'webrick'
require 'json'
require 'erb'
require "./jenkins_build_search.rb"

include WEBrick
#include 'jenkins_build_search.rb'

def start_webrick(config = {})
  config.update(:Port => 9955)
  server = HTTPServer.new(config)
  yield server if block_given?
  ['INT', 'TERM'].each { |signal|
    trap(signal) { server.shutdown }
  }
  server.start
end

class RestServlet < HTTPServlet::AbstractServlet


  def do_GET(req, resp)

    if req.path=='/'
      resp.body = File.read('index.html')
      raise HTTPStatus::OK
      return
    end
    if req.path=='/go_jenkins'
      #resp.body = File.read('index.html')
      myjaddr=req.query['jaddr']
      myjport=req.query['jport']
      @js=Jjobs::Jenkins_server.new(myjaddr, myjport)

      template = ERB.new(File.read('step1.erb'))

      job_array= Jjobs::get_jobs(@js.host, @js.port)
      resp.body = template.result(binding)
      raise HTTPStatus::OK
      return
    end
    if req.path=='/go_jobs'
      #resp.body = File.read('index.html')
      myjaddr=req.query['jaddr']
      myjport=req.query['jport']
      myjob= req.query['jjob']
      @js=Jjobs::Jenkins_server.new(myjaddr, myjport)
      jj=Jjobs::Jenkins_job.new(@js, myjob)
      par_array=jj.get_params
      if  par_array.nil?
        resp.body = "<h1>Oops... For this job -  #{myjob} params not found ! <h1>"
        raise HTTPStatus::NotFound
      else
        template = ERB.new(File.read('step2.erb'))
        resp.body = template.result(binding)
        raise HTTPStatus::OK
      end

      return
    end

    if req.path=='/go_search'
      #resp.body = File.read('index.html')
      myjaddr=req.query['jaddr']
      myjport=req.query['jport']
      myjob= req.query['jjob']
      myjparam=req.query['jparam']
      myjval= req.query['jval']
      mycount= req.query['jcount']
      @js=Jjobs::Jenkins_server.new(myjaddr, myjport)
      jj=Jjobs::Jenkins_job.new(@js, myjob)
      template = ERB.new(File.read('step3.erb'))
      jobs_links= jj.search_by_params({myjparam => myjval}, false, mycount.to_i)
      resp.body = template.result(binding)
      raise HTTPStatus::OK
      return
    end
    if req.path=='/favicon.ico'
      resp.body = File.read('favicon.ico')
      raise HTTPStatus::OK
      return
    end
    raise HTTPStatus::NotFound
  end
end

start_webrick { |server|
  server.mount('/', RestServlet)
}