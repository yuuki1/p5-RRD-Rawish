use utf8;
use strict;
use warnings;
use lib lib => 't/lib';

use Test::More;
use Test::Fatal;

use RRDTool::Rawish;
use RRDTool::Rawish::Test;

my $rrdtool_path = '/usr/local/bin/rrdtool';
my $rrd_file     = './rrd_test.rrd';

subtest no_rrdfile => sub {
    my $rrd = RRDTool::Rawish->new(+{
            command => $rrdtool_path,
        });
    my $params = ['テスト'];
    for (qw(create update dump restore lastupdate fetch info)) {
        like exception { $rrd->$_($params) }, qr(Require rrdfile);
    }
};

subtest parameter_type_mismatch => sub {
    my $rrd = RRDTool::Rawish->new(
        command => $rrdtool_path,
        rrdfile => $rrd_file,
    );

    my ($params, $opts);
    subtest invalid_param_type => sub {
        for (qw(create update graph xport)) {
            $params = 'Arrayじゃない';
            like exception { $rrd->$_($params) }, qr(Not ARRAY);
        }
        for (qw(create update graph dump xport)) {
            $params = [1, 2];
            $opts = 'Hashじゃない';
            like exception { $rrd->$_($params, $opts) }, qr(Not HASH);
        }
        for (qw(fetch restore)) {
            like exception { $rrd->$_() }, qr(Require);

            my $param = "スカラー";
            $opts = 'Hashじゃない';
            like exception { $rrd->$_($param, $opts) }, qr(Not HASH);
        }
    }
};

subtest rrdtool_syntax_error => sub {
    my $rrd = RRDTool::Rawish->new(
        command => $rrdtool_path,
        rrdfile => $rrd_file,
    );

    for (qw(create update graph xport)) {
        $rrd->$_([], {'--invalid' => 'aaa' });
        like $rrd->errstr, qr/^ERROR:/;
    }
    for (qw(fetch restore)) {
        $rrd->$_("", {'--invalid' => 'aaa' });
        like $rrd->errstr, qr/^ERROR:/;
    }
    $rrd->dump({}, {'--invalid' => 'aaa' });
    like $rrd->errstr, qr/^ERROR:/;
};

done_testing;
