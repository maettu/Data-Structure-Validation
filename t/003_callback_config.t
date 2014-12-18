#!/usr/bin/perl
use Test::More;

# XXX remove dependency by transforming config.json
#~ use Mojo::JSON qw(decode_json);
#~
#~ print `pwd`;
#~ open my $fh, '<', 't/config.json' or die $!;
#~ my $c;
#~ $c .= $_ while (<$fh>);
#~ my $config = decode_json($c);

my $config = {
  "DATA" => {
    "job_1" => {
      "archive" => {
        "a1" => {
          "consolidation" => "AVERAGE",
          "rows" => 1000,
          "steps" => 1,
          "xff" => "0.5"
        },
        "a2" => {
          "consolidation" => "AVERAGE",
          "rows" => 1000,
          "steps" => 6,
          "xff" => "0.5"
        },
        "a3" => {
          "consolidation" => "AVERAGE",
          "rows" => 1000,
          "steps" => 60,
          "xff" => "0.5"
        },
        "a3max" => {
          "consolidation" => "MAX",
          "rows" => 1000,
          "steps" => 60,
          "xff" => "0.5"
        },
        "a3min" => {
          "consolidation" => "MIN",
          "rows" => 1000,
          "steps" => 60,
          "xff" => "0.5"
        }
      },
      "basegraph" => {
        "chart" => [
          "DEF:d=<% \$ds %>.rrd:AVERAGE",
          "LINE:d#f00:<% \$ds %>"
        ],
        "lower-limit" => 0,
        "title" => "<% \$host %> - <% \$ds %>"
      },
#~       "datasource" => {
#~         "maximum" => "U",
#~         "minimum" => 0,
#~         "probe" => "SnmpGetBulk",
#~         "probe_cfg" => {
#~           "community" => "public",
#~           "host" => "runip123",
#~           "oids" => {
#~             "1.3.6.1.2.1.2.2.1.10" => "inOctets",
#~             "1.3.6.1.2.1.2.2.1.16" => "outOctets"
#~           },
#~           "version" => "2c"
#~         },
#~         "step" => 2,
#~         "type" => "DERIVE"
#~       }
    }
  },
  "GENERAL" => {
    "cachedb" => "/tmp/n3k-cache.db",
#~     "default_template" => [
#~       "snmpgetlocal",
#~       "oneyear",
#~       "simplegraph"
#~     ],
    "history" => 3600,
    "logfile" => "/tmp/n3k-harvester.log",
    "silos" => {
      "silo-a" => {
        "key" => "my-secret-shared-key",
        "url" => "https://silo-a/api"
      },
      "silo-b" => {
        "key" => "my-other-very-secret-key",
        "url" => "https://silo-b/api"
      }
    }
  }
};


use lib 'lib';
use Data::Structure::Validation;


sub probeInventory {
    my $self   = shift;
    my $probePath = $self->probePath;
    my %probes;
    for my $path (@INC){
        for my $pPath (@$probePath) {
            my @pDirs = split /::/, $pPath;
            my $fPath = File::Spec->catdir($path, @pDirs, '*.pm');
            for my $file (glob($fPath)) {
                my ($volume, $modulePath, $moduleName) = File::Spec->splitpath($file);
                $moduleName =~ s{\.pm$}{};
                $probes{$moduleName} = {
                    module => $pPath.'::'.$moduleName,
                    file => $file
                }
            }
        }
    }
    return \%probes;
};


my $validator = {
    file => sub {
        my $op = shift;
        my $msg = shift;
        print "op: $op, msg: $msg";
        # XXX in welchem Kontext wird das ausgeführt?
        sub {
            my $file = shift;
            # XXX return undef, und was ist mit dem offenen $fh, das wird gleich wieder geschlossen?
            open my $fh, $op, $file and return undef;
            return "$msg $file: $!";
        }
    },
    rx => sub {
        my $rx = shift;
        my $msg = shift;
        sub {
            my $value = shift;
            if ($value =~ /^$rx$/){
                return undef;
            }
            return "$msg ($value)";
        }
    },
    any => sub {
        my $array = shift;
        my %hash = ( map { $_ => 1 } @$array );
        sub {
            my $value = shift;
            if ($hash{$value}){
                return undef;
            }
            return "expected one value from the list: ".join(', ',@$array);
        }
    },
};


my $timespecfactor = {
    d => 24*3600,
    m => 60,
    s => 1,
    h => 3600
};


my $transformer = {
    timespec => sub {
        my $msg = shift;
        sub {
            if (shift =~ /(\d+)([dmsh]?)/){
                return ($1 * $timespecfactor->{($2 || 's')});
            }
            die $msg;
        }
    }
};



my $schema =   {
    GENERAL => {
        mandatory   => 1,
        description => 'general settings',
        members => {
            logfile => {
                validator   => $validator->{file}('>>','writing'),
                description => 'absolute path to logfile',
                mandatory   => 1,
            },
            cachedb => {
                validator   => $validator->{file}('>>','writing'),
                description => 'absolute path to cache (sqlite) database file',
                mandatory   => 1,
            },
            history => {
                default     => '1d',
                description => 'time to keep history in cache database. specify in s m h d',
                example     => '3h',
                transformer => $transformer->{timespec}(
                    'specify cachedb timeout in seconds or append d,m,h to the number'),
                mandatory   => 1,
            },
            silos => {
                mandatory   => 1,
                description => 'silos store collected data',
                # "members" stands for all "non-internal" fields
                members => {
                    'silo-.+' => {
                        regex   => 1,
                        members => {
                            url => {
                                mandatory   => 1,
                                validator   => $validator->{rx}(qr{https://.*},'expected a https url'),
                                description => 'url of the silo server. Only https:// allowed',
                            },
                            key => {
                                mandatory   => 1,
                                description => 'shared secret to identify node'
                            }
                        }
                    }
                }
            }
        }
    },
    # TEMPLATE ... the templates get applied before the validate and transform step
    DATA => {
        mandatory   => 1,
        description => 'Data section',
        members => {
            '.+' => {
                regex   => 1,
                members => {
                    datasource => {
                        members => {
                            type => {
                                mandatory   => 1,
                                description => 'data source type',
                                validator   => $validator->{any}(qw(DERIVE COUNTER GAUGE)),
                            },
                            step => {
                                mandatory   => 1,
                                description => 'step width in seconds for to accquire this datasource',
                            },
                            minimum => {
                                mandatory   => 1,
                                description => 'maximum acceptable input value',
                            },
                            maximum => {
                                mandatory   => 1,
                                description => 'minimum acceptable input value',
                            },
                            probe_cfg => {
                                mandatory   => 1,
                                description => 'dummy entry. this will be replaces once the probe is loaded',
                            },
                            probe => {
                                mandatory   => 1,
                                description => 'Probe Module to load for this section',
                                transformer => sub {
                                    my $value = shift;
                                    return {
                                        name => $value,
                                        obj  => $self->LoadProbe($value),
                                    };
                                },
                                schema_gen => sub {
                                    # XXX $data?
                                    my $data   = shift;
                                    my $schema = shift; # schema parent section
                                    # XXX whatsthat?
                                    $schema->{probe_cfg} = $data->{probe}{obj}->schema;
                                    return $schema;
                                },
                                # a list of values to use when generating documentation
                                # so that all plugins can be loaded artificially
                                doc_gen => sub {
                                    [ sort keys %{probeInventory()} ]
                                },
                            },
                        },
                    },
                    archive => {
                        members => {
                            '.+' => {
                                regex => 1,
                                members => {
                                    consolidation => {
                                        mandatory   => 1,
                                        description => 'consolidation function (AVERAGE|MIN|MAX)',
                                        # missing 2nd parameter
                                        validator   => $validator->{any}(qw(AVERAGE MIN MAX)),
                                    },
                                    xff => {
                                        mandatory   => 1,
                                        description => 'X File Factor',
                                    },
                                    steps => {
                                        mandatory   => 1,
                                        description => 'how many base steps to consolidate into a ',
                                        },
                                    rows => {
                                        mandatory   => 1,
                                        description => 'how many rows of data to keep at this resolution',
                                    }
                                }
                            }
                        }
                    },
                    basegraph => {
                        members => {
                            "chart" => {
                                description => 'rrdtool graph instructions',
#~                                 validator   => sub {
#~                                     if ( ref $_[0] eq 'ARRAY' ){
#~                                         return undef;
#~                                     }
#~                                     return "Expected an array";
#~                                 }
                                validator => sub {return undef;}
                            },
                            '.+' => {
                                description => 'rrdtool command line options',
                                regex       => 1
                            }
                        }
                    }
                }
            }
        }
    }
};

my $validator = Data::Structure::Validation->new($schema);
isa_ok( $validator, Data::Structure::Validation, '$checker' );

my @errors = $validator->validate($config, verbose=>1);

for my $error (@errors){
    print "$error\n";
}



done_testing;
