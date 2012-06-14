module Jjobs

  require 'json'
  require 'net/http'
  require 'uri'

  class Jenkins_server
    attr_accessor :host, :port

    def initialize (jhost, jport)
      @host = jhost
      @port = jport.to_i
    end
  end

  class Jenkins_job

    def initialize (jserv, jname)
      @jserv=jserv
      @jname=jname
      @stat={:params=>nil, :builds=>nil}
      update_status
    end

    def update_status
      @stat=Jjobs::get_job_params(@jserv.host, @jserv.port, @jname)
    end

    def get_params
      @stat[:params]
    end

    def get_first_builds_num

      @stat[:f_build]
    end

    def get_last_builds_num
      @stat[:l_build]
    end

    def print_params
      get_params.each { |x| puts x }
    end

    def search_by_params (shash, or_oper=true, build_count=0)

      barr=[]

      return nil if (shash.nil? or shash.empty?)
      predel = get_last_builds_num-build_count+1
      predel=get_first_builds_num if (build_count==0 or (predel < 1) or (predel < get_first_builds_num))


      shash.each_key { |x|
        return nil unless get_params.include?(x)
      }

      get_last_builds_num.downto(predel) { |z|
        arr={}
        Jjobs::getarr(@jserv.host, @jserv.port, '/job/'+@jname+'/'+z.to_s.strip+'/api/json')['actions'][0]['parameters'].each do |x|
          arr.update({x['name'] => x['value']})
        end
        #puts arr.inspect
        barr << z if hash_search(arr, shash, or_oper)


      }

      barr
    end


    def hash_search (hash1, hash2, or_flag=true)
      return false if (hash1.nil? or hash2.nil? or hash1.empty? or hash2.empty?)
      and_count=0
      hash2.each_key { |k|
        if  Regexp.new(hash2[k])=~hash1[k]
          return true if or_flag
          and_count+=1
        else
          return false unless or_flag
        end
      }

      return true if  and_count==hash2.size
      false
    end
  end

  def self.web_print_jobs(jserver)
    get_jobs(jserver.host, jserver.port).each { |x| puts x }
  end


  def self.getarr(host, port, qstring)
    res = Net::HTTP.start(host, port) { |http|
      http.get(qstring)
    }
    JSON.parse(res.body)
  end

  def self.get_jobs(host, port)
    arr=[]
    getarr(host, port, '/api/json?tree=jobs[name]')['jobs'].each do |x|
      arr<<x['name']
    end
    arr
  end

  def self.get_job_params(host, port, jobname)
    raise "Bad job name" unless  get_jobs(host, port).include?(jobname)
    arr=[]
    mhash=getarr(host, port, '/job/'+jobname+'/api/json/')
    mhash['actions'][0]['parameterDefinitions'].each do |x|
      arr<<x['name']
    end

    {:params => arr, :f_build => mhash['firstBuild']['number'], :l_build => mhash['lastBuild']['number']}
  end


end


if __FILE__ == $0
  lasts=5
  jname='Monitoring_Registration'
  js=Jjobs::Jenkins_server.new('j.xcom', '80')
  # puts "\n jobs:"
  #Jjobs.web_print_jobs js

  jj=Jjobs::Jenkins_job.new(js, jname)
  puts "\n params for #{jname}:"
  jj.print_params
  puts "\n num builds  for #{jname}:"
  puts "#{jj.get_first_builds_num} .. #{jj.get_last_builds_num} search from last #{lasts}"

  jj.search_by_params({'VM_ROLES' => 'cf_dea'}, false, lasts).each { |x| puts x }
end