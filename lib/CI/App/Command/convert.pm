package CI::App::Command::convert;
########################################################################
# ABSTRACT:  command line app to convert jenkins xml jobs into jenkins
#            job builder format
########################################################################
use Moose;
use CI::Job::Driver;

extends qw(MooseX::App::Cmd::Command);

has xml_dir => (isa=>'Str',
                is=>'ro',
                required=>1,
                documentation=>'location of xml jenkins job');

has yaml_dir => (isa=>'Str',
                 is=>'ro',
                 required=>1,
                 documentation=>'destination of the yaml job files');

sub execute {
  my ($self, $opt, $args) = @_;
  my $app = CI::Job::Driver->new($args);
  $app->create_yaml_jobs($opt, $args);
}

sub run  {
    my $args = {'xml_dir'=>$ENV{JJBC_JOB_DIR}, 'yaml_dir'=>$ENV{JJBC_YAML_DIR};
    my $cmd_obj = CI::App::Command::convert->new($args);
    $cmd_obj->execute();
}

run() unless caller;

no Moose;
1;
