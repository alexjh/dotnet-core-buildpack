# Encoding: utf-8
# ASP.NET Core Buildpack
# Copyright 2014-2016 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'yaml'
require 'json'
require_relative '../sdk_info'

module AspNetCoreBuildpack
  class DotnetFrameworkVersion
    include SdkInfo

    def initialize(build_dir, nuget_cache_dir)
      @build_dir = build_dir
      @nuget_cache_dir = nuget_cache_dir
      @out = Out.new
    end

    def versions
      runtime_config_json_file = Dir.glob(File.join(@build_dir, '*.runtimeconfig.json')).first

      framework_versions = []

      if !runtime_config_json_file.nil?
        runtime_config_framework = get_version_from_runtime_config_json(runtime_config_json_file)
        framework_versions.push runtime_config_framework unless runtime_config_framework.nil?
      elsif restored_framework_versions.any?
        out.print("Detected .NET Core runtime version(s) #{restored_framework_versions.join(', ')} required according to 'dotnet restore'")
        framework_versions += restored_framework_versions
      else
        raise 'Unable to determine .NET Core runtime version(s) to install'
      end

      framework_versions.uniq
    end

    private

    def restored_framework_versions
      if project_json?(@build_dir)
        netcore_app_dir = 'Microsoft.NETCore.App'
      elsif msbuild?(@build_dir)
        netcore_app_dir = 'microsoft.netcore.app'
      end

      Dir.glob(File.join(@nuget_cache_dir, 'packages', netcore_app_dir, '*')).sort.map do |path|
        File.basename(path)
      end
    end

    def get_version_from_runtime_config_json(runtime_config_json_file)
      begin
        global_props = JSON.parse(File.read(runtime_config_json_file, encoding: 'bom|utf-8'))
      rescue
        raise "#{runtime_config_json_file} contains invalid JSON"
      end

      has_framework_version = global_props.key?('runtimeOptions') &&
                              global_props['runtimeOptions'].key?('framework') &&
                              global_props['runtimeOptions']['framework'].key?('version')

      return nil unless has_framework_version

      version = global_props['runtimeOptions']['framework']['version']
      out.print("Detected .NET Core runtime version #{version} in #{runtime_config_json_file}")

      version
    end

    attr_reader :out
  end
end
