require 'spec_helper'

describe 'selenium_test::hub' do
  let(:shellout) { double(run_command: nil, error!: nil, stdout: ' ') }

  before { allow(Mixlib::ShellOut).to receive(:new).and_return(shellout) }

  context 'windows' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'windows', version: '2008R2', step_into: ['selenium_hub']) do |node|
        node.set['java']['windows']['url'] = 'http://ignore/jdk-windows-64x.tar.gz'
        stub_command("netsh advfirewall firewall show rule name=\"selenium_hub\" > nul").and_return(false)
      end.converge(described_recipe)
    end

    it 'installs selenium_hub server' do
      expect(chef_run).to install_selenium_hub('selenium_hub')
    end

    it 'creates hub config file' do
      expect(chef_run).to create_template('C:/selenium/config/selenium_hub.json').with(
        source: 'hub_config.erb',
        cookbook: 'selenium'
      )
    end

    it 'install selenium_hub' do
      expect(chef_run).to install_nssm('selenium_hub').with(
        program: 'C:\\Windows\\System32\\java.exe',
        args: '-jar """C:/selenium/server/selenium-server-standalone.jar"""'\
          ' -role hub -hubConfig """C:/selenium/config/selenium_hub.json"""',
        params: {
          AppDirectory: 'C:/selenium',
          AppStdout: 'C:/selenium/log/selenium_hub.log',
          AppStderr: 'C:/selenium/log/selenium_hub.log',
          AppRotateFiles: 1
        }
      )
    end

    it 'creates firewall rule' do
      expect(chef_run).to run_execute('Firewall rule selenium_hub for port 4444')
    end

    it 'reboots windows server' do
      expect(chef_run).to_not request_windows_reboot('Reboot to start selenium_hub')
    end
  end

  context 'linux' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(
        platform: 'centos', version: '7.0', step_into: ['selenium_hub']).converge(described_recipe)
    end

    it 'installs selenium_hub server' do
      expect(chef_run).to install_selenium_hub('selenium_hub')
    end

    it 'creates hub config file' do
      expect(chef_run).to create_template('/usr/local/selenium/config/selenium_hub.json').with(
        source: 'hub_config.erb',
        cookbook: 'selenium'
      )
    end

    it 'install selenium_hub' do
      expect(chef_run).to create_template('/etc/init.d/selenium_hub').with(
        source: 'rhel_initd.erb',
        cookbook: 'selenium',
        mode: '0755',
        variables: {
          name: 'selenium_hub',
          exec: '/usr/bin/java',
          args: '-jar "/usr/local/selenium/server/selenium-server-standalone.jar" -role hub '\
            '-hubConfig "/usr/local/selenium/config/selenium_hub.json"',
          display: nil,
          port: 4444
        }
      )
    end

    it 'start selenium_hub' do
      expect(chef_run).to_not start_service('selenium_hub')
    end
  end
end
