my $root;

BEGIN {
  use File::Basename ();
  use File::Spec     ();
  $root = File::Basename::dirname(__FILE__);
  $root = File::Spec->rel2abs($root);
    unshift @INC, "$root/../../lib";
}

use Test::Routine;
use Test::Routine::Util;
use Test::More;
use Test::Moose;
use CI::Job::Driver;

has config => (is=>'rw', lazy_build=>1);
has test_cfg_file_path => (is=>'rw', lazy_build=>1);

sub BUILD {
  my  $self = shift;
  return $self;
}

# Round trip test of converting to yaml then back to xml and diffing with original
test 'process conversion request' => sub {
    my $self = shift;
    my $response = undef;
    my $expected = undef;
    if($response) {
      plan tests => 1;
      is_deeply($response, $expected, 'Conversion from xml to yaml successful');
    }
};

sub _build_config {
  my $self = shift;
}

sub _build_test_cfg_file_path {
  my $self = shift;
  my $path = ${JJBC_CFG_PATH};
  return $path;
}

run_me();
done_testing();
1;
