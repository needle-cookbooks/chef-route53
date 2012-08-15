action :create do
  require "fog"
  require "nokogiri"

  def name
    @name ||= new_resource.name + "."
  end

  def value
    @value ||= new_resource.value
  end

  def type
    @type ||= new_resource.type
  end

  def ttl
    @ttl ||= new_resource.ttl
  end

  def overwrite
    @overwrite ||= new_resource.overwrite
  end

  def zone_id
    unless new_resource.zone_id.match(/^[A-Z0-9]{14}$/) # should match zone identifiers
      if new_resource.zone_id.match(/\.$/) # lets add a trailing . to domains which lack them
        zone_name = new_resource.zone_id
      else
        zone_name = new_resource.zone_id + "."
      end
      @id ||= @zones.reject!{|z| z.domain != zone_name }.first.id
    else
      new_resource.zone_id
    end
  end

  def zone
    zones.get(zone_id)
  end

  def zones
    @zones ||= Fog::DNS.new({ :provider => "aws",
                             :aws_access_key_id => new_resource.aws_access_key_id,
                             :aws_secret_access_key => new_resource.aws_secret_access_key }
                           ).zones
  end

  def create
    begin
      zone.records.create({ :name => name,
                            :value => value,
                            :type => type,
                            :ttl => ttl })
    rescue Excon::Errors::BadRequest => e
      Chef::Log.info Nokogiri::XML( e.response.body ).xpath( "//xmlns:Message" ).text
    end
  end

  record = zone.records.all.select do |record|
    record.name == name && record.type == type
  end.first

  if record.nil?
    create
    Chef::Log.info "Record created: #{name}"
  elsif value != record.value.first
    if overwrite
      record.destroy
      create
    Chef::Log.info "Record modified: #{name}"
    else
      Chef::Log.info "Record should have been modified but overwrite is disabled."
    end
  end

end
