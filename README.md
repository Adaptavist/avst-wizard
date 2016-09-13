# Avst::Wizard

Executable gem that completes wizard of Atlassian products.

## Installation

Add this line to your application's Gemfile:

    gem 'avst-wizard'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install avst-wizard

## Usage

avst-wizard --hostname hostname --product_type product_type --base_url url --hiera_config config --custom_config custom_config --ops

- hostname - will reference custom hiera config
- product_type   - the product, one of (bamboo, confluence, crowd, fisheye, jira, stash)
- url            - url to access the instance, http://jira.vagrant or http://jira.vagrant:8090
- hiera_config   - custom hiera.yaml file, defaults to hiera.yaml in project root
- custom_config  - file with required params setup, defaults to config/config.yaml
- ops            - Prints out required parameters to set for specified product
-p, --use_tomcat_port PORT  - Use tomcat port to connect to the application

## Default usage and configuration

Each Atlassian app requires in default usage parameters. The list per product_type can be displayed while running

```
avst-wizard --product_type "product_type" --ops
```

In the file defined by "custom_config" you have to specify all required params that will be passed to hiera config.

## Advanced configuration

Stages configuration is stored in hiera. Default stages flow is provided with the app and stored in config/hiera/"product_type"/default.yaml. You can specify custom values by providing them in "hostname".yaml file in "product_type" folder of hiera config folder. You can overwrite/add any value in default.yaml config via user_data hash.

Look at examples provided for details. The examples are all configuring the app to use local mysql database.

### Config details

Each wizard consist of stages.

#### Simple setup
Stage is uniquely identifiable by request_uri part of url without params.
So http://wiki.vagrant/console/setup/setuplicense.action will be identified by /console/setup/setuplicense.action
In case this is not possible and two stages have the same url, refer to complex setup.

For each stage there is a POST request that will submit a form. You can specify the "post_url" per stage and "values" that will be submitted at this stage.

default.yaml

```
stages:
    '/setup/setupLicense.action':
        post_url: 'setup/validateLicense.action'
        values:
            licenseString: "key"
            app_name: "testing"
```

"hostname".yaml

```
user_data:
    '/setup/setupLicense.action':
        values:
            licenseString: |
                AAABEg0ODAoPeNp9kMtugzA
```

Will result into POST call to "url"/setup/validateLicense.action with params licenseString="AAABEg0ODAoPeNp9kMtugzA" and app_name="testing" for stage accessible via url "url"/setup/setupLicense.action

#### Complex setup

In case the stage can not be identified uniquely via string, so some ajax calls are done or whatever, you can mark the stage with complex: true and specify substages. Those are uniquely identified by "key=value" pair that has to be present as attribute and value of an element in the html code of the stage.

```
    '/setup':
        complex: true
        substages:
            'id="database"':
                parse_atl_token: true
                post_url: 'setup'
                values:
                    type: "mysql"
            'id="license"':
                parse_atl_token: true
                post_url: 'setup'
                values:
                    'license': '1234'
```

This example identifies 2 substages for "url"/setup stage identified by id="database" and id="license" present as attribute and value of some element. And will result into POST request to "url"/setup with params set to type: "mysql" and POST with params 'license': '1234' accordingly.

##### XSRF

Flag parse_atl_token: true refers to XSRF token sometimes required to submit the requests and will be parsed from the form from element with name="atl_token" from attribute value. TODO: may do this configurable...

##### Ajax waiting for ready state from server

In case of ajax calls where the response is returned and the app is waiting for server side process to finish and only then it will redirect to next stage we can setup wait_for_next_state with param number of retries with sleep 5 sec that will wait and once done will redirect.

## Important
In case there is proxy in front of the app, as there are stages in wizard that takes long time, make sure you set Proxy timeout to sufficient value.

## Supported versions

Tested with versions:

- fisheye/cru - 3.4.3, 3.6.2
- crowd - 2.7.2, 2.6.4, 2.8.0, 2.8.3
- confl - 5.6.3, 5.2.5, 5.3.1, 5.8.10, 5.7.3
- bamboo - 5.7.1, 5.6.0, 5.9.4
- jira  - 6.3.6, 6.2.7, 6.4.11, 7.0.9, 7.1.7
- bitbucket - 2.0.3, 3.6.0, 4.0.0

## License

avst-wizard is released under the terms of the Apache 2.0 license. See LICENSE.txt

## Contributing

1. Fork it ( https://github.com/adaptavist/avst-wizard/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
