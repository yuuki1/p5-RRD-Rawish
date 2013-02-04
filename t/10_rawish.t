use utf8;
use strict;
use warnings;
use lib lib => 't/lib';

use Test::More;
use Test::Mock::ExternalCommand;

use File::Which qw(which);

use RRD::Rawish;
use RRD::Rawish::Test qw(rrd_create rrd_setup);

my $rrdtool_path = '/usr/local/bin/rrdtool';
my $rrd_file     = './rrd_test.rrd';
my $remote_host  = 'hogerrd.com:111111';

subtest constructor => sub {
    {
        my $rrd = RRD::Rawish->new(
            rrdtool_path => $rrdtool_path,
            rrdfile => $rrd_file,
            remote  => $remote_host,
        );

        if (ok $rrd) {
            is $rrd->{command}, $rrdtool_path;
            is $rrd->{rrdfile}, $rrd_file;
            is $rrd->{remote},  $remote_host;
        }
    }

    {
        my $rrd = RRD::Rawish->new(+{
            rrdtool_path => $rrdtool_path,
            rrdfile => $rrd_file,
            remote  => $remote_host,
        });

        if (ok $rrd) {
            is $rrd->{command}, $rrdtool_path;
            is $rrd->{rrdfile}, $rrd_file;
            is $rrd->{remote},  $remote_host;
        }
    }
};

subtest create => sub {
    if (-f $rrd_file) {
        unlink $rrd_file;
    }
    my $rrd = RRD::Rawish->new(+{
        rrdtool_path => $rrdtool_path,
        rrdfile => $rrd_file,
    });
    my $params = [
        "DS:rx:DERIVE:40:0:U",
        "DS:tx:DERIVE:40:0:U",
        "RRA:LAST:0.5:1:30240",
    ];
    my $opts = +{
        '--start'        => '1350294469',
        '--step'         => '20',
        '--no-overwrite' => '1',
    };

    my $ret = $rrd->create($params, $opts);

    is $ret, 0;
    if (ok -f $rrd_file) {
        unlink $rrd_file;
    }
};

subtest update => sub {
    my $rrd = rrd_create($rrd_file);
    my $cmd = "update $rrd_file --template dsname 1350294020:0:0 1350294040:50:100";
    my $mock = Test::Mock::ExternalCommand->new;
    $mock->set_command_by_coderef($rrdtool_path, sub { is join(" ", @_), $cmd });
    my $params = [
        "1350294020:0:0",
        "1350294040:50:100",
    ];
    $rrd->update($params, +{
        '--template' => "dsname",
    });
    unlink $rrd_file;
};

subtest graph => sub {
    my $rrd = rrd_setup($rrd_file);
    my $cmd = "graph --end now --imgformat PNG --start end-1y DEF:rx=$rrd_file:rx:LAST DEF:tx=$rrd_file:tx:LAST LINE1:rx#00F000 LINE1:tx#0000F0";

    my $mock = Test::Mock::ExternalCommand->new;
    $mock->set_command_by_coderef($rrdtool_path, sub { is(join(" ", @_), $cmd); return "aaa"; });

    my $params = [
        "DEF:rx=$rrd_file:rx:LAST",
        "DEF:tx=$rrd_file:tx:LAST",
        "LINE1:rx#00F000",
        "LINE1:tx#0000F0",
    ];
    my $opts = +{
        '--imgformat' => 'PNG',
        '--end'       => 'now',
        '--start'     => 'end-1y',
    };

    $rrd->graph($params, $opts);

    unlink $rrd_file;
};

subtest dump => sub {
    my $rrd = rrd_create($rrd_file);

    my $cmd = "dump $rrd_file --no-header";
    my $mock = Test::Mock::ExternalCommand->new;
    $mock->set_command_by_coderef($rrdtool_path, sub { is(join(" ", @_), $cmd) });
    $rrd->dump(+{ '--no-header' => 1 });

    unlink $rrd_file;
};

subtest restore => sub {
    my $rrd = rrd_create($rrd_file);

    my $xmlfile = "aaa.xml";
    my $cmd = "restore $xmlfile $rrd_file --range-check";
    my $mock = Test::Mock::ExternalCommand->new;
    $mock->set_command_by_coderef($rrdtool_path, sub { is(join(" ", @_), $cmd) });
    $rrd->restore($xmlfile, +{ '--range-check' => 1 });

    unlink $rrd_file;
};

subtest lastupdate => sub {
    my $rrd = rrd_create($rrd_file);

    my $cmd = "lastupdate $rrd_file";
    my $output = <<'EOS';
 rx tx

1350294000: U U
END
EOS

    my $mock = Test::Mock::ExternalCommand->new;
    $mock->set_command($rrdtool_path, $output, 0);
    my $result = $rrd->lastupdate;

    is $result, 1350294000;

    unlink $rrd_file;
};

subtest fetch => sub {
    my $rrd = rrd_create($rrd_file);

    my $output = <<'EOS';
                                 rx                  tx

1359296860: nan nan
1359296880: nan nan
1359296900: nan nan
1359296920: nan nan
1359296940: nan nan
1359296960: nan nan
1359296980: nan nan
1359297000: nan nan
1359297020: nan nan
1359297040: nan nan
1359297060: nan nan
END
EOS
    my $mock = Test::Mock::ExternalCommand->new;
    $mock->set_command($rrdtool_path, $output, 0);
    my $lines = $rrd->fetch('LAST');
    my $dsnames = [ split ' ', shift @$lines ];

    is_deeply $dsnames, [qw(rx tx)];

    shift @$lines;
    for (0..5) {
        like $lines->[$_], qr(^\d+: (\d+|nan|NaN) (\d+|nan|NaN)$);
    }

    unlink $rrd_file;
};

subtest xport => sub {
    my $rrd = rrd_create($rrd_file);

    my $cmd = "xport DEF:rx=$rrd_file:output:LAST DEF:tx=$rrd_file:output:LAST XPORT:rx:out bytes";
    my $mock = Test::Mock::ExternalCommand->new;
    $mock->set_command_by_coderef($rrdtool_path, sub { is(join(" ", @_), $cmd) });
    my $params = [
        "DEF:rx=$rrd_file:output:LAST",
        "DEF:tx=$rrd_file:output:LAST",
        "XPORT:rx:out bytes",
    ];
    $rrd->xport($params);

    unlink $rrd_file;
};

subtest info => sub {
    my $rrd = rrd_create($rrd_file);
    my $output = <<TEXT;
filename = "rrd_test.rrd"
rrd_version = "0003"
step = 20
last_update = 1350294000
header_size = 904
ds[rx].index = 0
ds[rx].type = "DERIVE"
ds[rx].minimal_heartbeat = 40
ds[rx].min = 0.0000000000e+00
ds[rx].max = NaN
ds[rx].last_ds = "U"
ds[rx].value = 0.0000000000e+00
ds[rx].unknown_sec = 0
ds[tx].index = 1
ds[tx].type = "DERIVE"
ds[tx].minimal_heartbeat = 40
ds[tx].min = 0.0000000000e+00
ds[tx].max = NaN
ds[tx].last_ds = "U"
ds[tx].value = 0.0000000000e+00
ds[tx].unknown_sec = 0
rra[0].cf = "LAST"
rra[0].rows = 240
rra[0].cur_row = 95
rra[0].pdp_per_row = 1
rra[0].xff = 5.0000000000e-01
rra[0].cdp_prep[0].value = NaN
rra[0].cdp_prep[0].unknown_datapoints = 0
rra[0].cdp_prep[1].value = NaN
rra[0].cdp_prep[1].unknown_datapoints = 0
TEXT

    my $mock = Test::Mock::ExternalCommand->new;
    $mock->set_command($rrdtool_path, $output, 0);
    my $value = $rrd->info();

    is $value->{filename}, "rrd_test.rrd";
    is $value->{rrd_version}, "0003";
    is $value->{step}, 20;
    is $value->{last_update}, 1350294000;
    is $value->{header_size}, 904;
    is $value->{ds}->{rx}->{index}, 0;
    is $value->{ds}->{rx}->{minimal_heartbeat}, 40;
    is $value->{ds}->{rx}->{min}, "0.0000000000e+00";
    is $value->{ds}->{rx}->{max}, "NaN";
    is $value->{ds}->{rx}->{last_ds}, "U";
    is $value->{ds}->{rx}->{value},  "0.0000000000e+00";
    is $value->{ds}->{rx}->{unknown_sec}, 0;
    is $value->{ds}->{tx}->{index}, 1;
    is $value->{ds}->{tx}->{type}, "DERIVE";
    is $value->{ds}->{tx}->{minimal_heartbeat}, 40;
    is $value->{ds}->{tx}->{min}, "0.0000000000e+00";
    is $value->{ds}->{tx}->{max}, "NaN";
    is $value->{ds}->{tx}->{last_ds}, "U";
    is $value->{ds}->{tx}->{value}, "0.0000000000e+00";
    is $value->{ds}->{tx}->{unknown_sec}, 0;
    is $value->{rra}->[0]->{cf}, "LAST";
    is $value->{rra}->[0]->{rows}, 240;
    is $value->{rra}->[0]->{cur_row}, 95;
    is $value->{rra}->[0]->{pdp_per_row}, 1;
    is $value->{rra}->[0]->{xff}, "5.0000000000e-01";
    is $value->{rra}->[0]->{cdp_prep}->[0]->{value}, "NaN";
    is $value->{rra}->[0]->{cdp_prep}->[0]->{unknown_datapoints}, 0;
    is $value->{rra}->[0]->{cdp_prep}->[1]->{value}, "NaN";
    is $value->{rra}->[0]->{cdp_prep}->[1]->{unknown_datapoints}, 0;

    unlink $rrd_file;
};

subtest daemon => sub {
    my $rrd = RRD::Rawish->new(+{
            command => $rrdtool_path,
            rrdfile => $rrd_file,
            remote  => $remote_host,
        });

    subtest create => sub {
        my $params = [ "DS:rx:DERIVE:40:0:U" ];
        my $cmd = "create $rrd_file --daemon $remote_host DS:rx:DERIVE:40:0:U";
        my $mock = Test::Mock::ExternalCommand->new;
        $mock->set_command_by_coderef($rrdtool_path, sub { is join(" ", @_), $cmd });
        $rrd->create($params);
    };
};


done_testing;
__END__
