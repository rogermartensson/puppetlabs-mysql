require 'spec_helper'

describe Puppet::Type.type(:mysql_database).provider(:mysql) do
  let(:defaults_file) { '--defaults-extra-file=/root/.my.cnf' }
  let(:parsed_databases) { ['information_schema', 'mydb', 'mysql', 'performance_schema', 'test'] }
  let(:provider) { resource.provider }
  let(:instance) { provider.class.instances.first }
  let(:resource) do
    Puppet::Type.type(:mysql_database).new(
      ensure: :present, charset: 'latin1',
      collate: 'latin1_swedish_ci', name: 'new_database',
      provider: described_class.name
    )
  end
  let(:raw_databases) do
    # rubocop:disable Layout/IndentHeredoc
    <<-SQL_OUTPUT
information_schema
mydb
mysql
performance_schema
test
    SQL_OUTPUT
    # rubocop:enable Layout/IndentHeredoc
  end

  before :each do
    Facter.stubs(:value).with(:root_home).returns('/root')
    Puppet::Util.stubs(:which).with('mysql').returns('/usr/bin/mysql')
    File.stubs(:file?).with('/root/.my.cnf').returns(true)
    provider.class.stubs(:mysql_caller).with('show databases', 'regular').returns('new_database')
    provider.class.stubs(:mysql_caller).with(["show variables like '%_database'", 'new_database'], 'regular').returns("character_set_database latin1\ncollation_database latin1_swedish_ci\nskip_show_database OFF") # rubocop:disable Metrics/LineLength
  end

  describe 'self.instances' do
    it 'returns an array of databases' do
      provider.class.stubs(:mysql_caller).with('show databases', 'regular').returns(raw_databases)
      raw_databases.each_line do |db|
        provider.class.stubs(:mysql_caller).with(["show variables like '%_database'", db.chomp], 'regular').returns("character_set_database latin1\ncollation_database  latin1_swedish_ci\nskip_show_database  OFF") # rubocop:disable Metrics/LineLength
      end
      databases = provider.class.instances.map { |x| x.name }
      expect(parsed_databases).to match_array(databases)
    end
  end

  describe 'self.prefetch' do
    it 'exists' do
      provider.class.instances
      provider.class.prefetch({})
    end
  end

  describe 'create' do
    it 'makes a database' do
      provider.class.expects(:mysql_caller).with("create database if not exists `#{resource[:name]}` character set `#{resource[:charset]}` collate `#{resource[:collate]}`", 'regular')
      provider.expects(:exists?).returns(true)
      expect(provider.create).to be_truthy
    end
  end

  describe 'destroy' do
    it 'removes a database if present' do
      provider.class.expects(:mysql_caller).with("drop database if exists `#{resource[:name]}`", 'regular')
      provider.expects(:exists?).returns(false)
      expect(provider.destroy).to be_truthy
    end
  end

  describe 'exists?' do
    it 'checks if database exists' do
      expect(instance).to be_exists
    end
  end

  describe 'self.defaults_file' do
    it 'sets --defaults-extra-file' do
      File.stubs(:file?).with('/root/.my.cnf').returns(true)
      expect(provider.defaults_file).to eq '--defaults-extra-file=/root/.my.cnf'
    end
    it 'fails if file missing' do
      File.stubs(:file?).with('/root/.my.cnf').returns(false)
      expect(provider.defaults_file).to be_nil
    end
  end

  describe 'charset' do
    it 'returns a charset' do
      expect(instance.charset).to eq('latin1')
    end
  end

  describe 'charset=' do
    it 'changes the charset' do
      provider.class.expects(:mysql_caller).with("alter database `#{resource[:name]}` CHARACTER SET blah", 'regular').returns('0')

      provider.charset = 'blah'
    end
  end

  describe 'collate' do
    it 'returns a collate' do
      expect(instance.collate).to eq('latin1_swedish_ci')
    end
  end

  describe 'collate=' do
    it 'changes the collate' do
      provider.class.expects(:mysql_caller).with("alter database `#{resource[:name]}` COLLATE blah", 'regular').returns('0')

      provider.collate = 'blah'
    end
  end
end
