package CI::Job::Driver;
# Abstract: Use to take existing jenkins xml files and create YAML in the jenkins-job-builder format
use Moose;
use File::Find;
use File::Spec::Functions qw(catfile splitdir);
use File::Slurp qw(write_file);
use MooseX::Types::Path::Class;
use XML::Simple;
use YAML;

has xml_dir => (is=>'ro',
                isa=>'Path::Class::Dir',
                required => 1,
                coerce=>1);

has yaml_dir => (is=>'ro',
                 isa=>'Path::Class::Dir',
                 required => 1,
                 coerce=>1);

has xml_files => (is=>'rw',
                  isa=>'ArrayRef',
                  lazy_build => 1);

has dictionary => (is=>'rw',
                   lazy_build=>1);

has tree => (is=>'rw');

# Extract all the jenkins job xml file paths and save them.
#$_[0]->store($_[0]->convert($_), $_) for (@{$_[0]->xml_files}) }
sub create_yaml_jobs {
    my ($self, $args) = @_;
    for my $filepath (@{$self->xml_files}) {
        $self->store($self->convert($filepath), $filepath);
    }
}

# input the xml job data and massage it into the jjb format
sub convert {
    my ($self, $xml_file) = @_;
    $self->tree(XMLin($xml_file));
    return $self->parse({data=>$self->tree});
}

# Persist the yaml jjb job data in a file
sub store {
    my ($self, $data, $filepath) = @_;
    my @vector = splitdir($filepath);
    my $job_file = $vector[-2];
    write_file(catfile($self->yaml_dir,  "$job_file.yaml"), YAML::Dump($data)); # 3: output formated yaml
}

sub lookup {
    my ($self, $args) = @_;
    my ($entry, $hash) = @$args{'entry', 'data'};
    if($self->dictionary->{$entry} eq 'CODEREF') {
        return $self->dictionary->{$entry}->();
    }
    else {
        my ($k, $v) = $self->dictionary->{$entry};
        return [$k, $v];
    }
}

# Walk the data and transform it into the key, value structure need by jjb
sub parse {
    my ($self, $args) = @_;
    my $data = $args->{data};

    my $callback = sub {
        my ($hash, $key, $val, $key_list) = @_;
        if ( $key  && $self->dictionary->{$key}) {
            my $result = $self->lookup({entry=>$key, data=>$hash});
            $hash->{$result->[0]} = $result->[1];
            delete $hash->{$key};
        }
    } || $args->{callback};

    $self->hash_walk($data, [], $callback);
    return $data;
}

# Walk the job data structure transforming as you go.
# This method is horrible
sub hash_walk {
    my ($self, $hash, $key_list, $callback) = @_;
    while (my ($k, $v) = each %$hash) {
        # Keep track of the hierarchy of keys, in case our callback needs it.
        push @$key_list, $k;
        if (ref($v) eq 'HASH') {
            if ($self->dictionary->{$k}) {
                my $result = $self->lookup({entry=>$k, data=>$hash});
                $hash->{$result->[0]} = $result->[1];
                delete $hash->{$k};
            }
            $self->hash_walk($v, $key_list, $callback);
        }
        elsif (ref($v) eq 'ARRAY') {
            for (my $i=0; $i < scalar @$v; $i++) {
                my $item = $v->[$i];
                if (ref($item) eq 'HASH') {
                    $self->hash_walk($item, $key_list, $callback);
                }
                if ( $self->dictionary->{$item}) {
                    my $result = $self->lookup({entry=>$k, data=>$item});
                    $v->[$i] = $result->[1];
                }
            }
        }
        else {  # A String
            $callback->($hash, $k, $v, $key_list);
        }

        if ($self->dictionary->{$k} && ! $hash->{ $self->dictionary->{$k} }) {
            $hash->{ $self->lookup({entry=>$k})->[0] } =  delete $hash->{$k};
        }

        pop @$key_list;
    }
}

sub _build_xml_files {
    my $self = shift;
    my @files = ();
    find(sub {push @files, $File::Find::name if ($_ =~ m{\.xml$} && $File::Find::dir !~ m/(?:builds|workspace)/)}, $self->xml_dir);
    return \@files;
}

sub _build_dictionary {
    return {
        'continuationCondition' => 'condition',
        'com.tikal.jenkins.plugins.multijob.PhaseJobsConfig' => 'projects',
        'hudson.model.Item.Build:Developers' => 'job-build',
        'hudson.model.Item.Workspace:Developers' => 'job-workspace',
        'hudson.model.Run.Update:Developers' => 'job-update',
        'hudson.model.Item.Discover:Developers' => 'job-discover',
        'hudson.model.Item.Cancel:Developers' => 'job-cancel',
        'hudson.scm.SCM.Tag:Developers' => 'scm-tag',
        'hudson.model.Item.Read:Developers' => 'job-read',
        'com.tikal.jenkins.plugins.multijob.MultiJobBuilder' => 'multijob',
        'phaseName' => 'phase-name',
        'phaseJobs' => 'phase-jobs',
        'jobName' => 'job-name',
        'blockBuildWhenDownstreamBuilding' => 'block-downstream',
        'blockBuildWhenUpstreamBuilding' => 'block-upstream',
        'buildWrappers' => 'build-wrappers',
        'mavenName' => 'maven-name',
        'usePrivateRepository' => 'use-private-repository',
        'artifactNumToKeep' => 'artifact-num-to-keep',
        'daysToKeep' => 'days-to-keep',
        'numToKeep' => 'num-to-keep',
        'hudson.security.AuthorizationMatrixProperty'=> 'authorization',
        'hudson.tasks.Maven' => 'maven',
        'parentJobName' => 'parent-job-name',
        'hudson.plugins.copyartifact.CopyArtifact' => 'copyartifact',
        'sendToIndividuals' => 'send-to-individuals',
        'concurrentBuild' => 'concurrent-build',
        'customWorkspace' => 'custom-workspace',
        'displayName' => 'display-name',
        'quietPeriod' => 'quiet-period',
        'keepDependencies' => 'keep-dependencies',
        'canRoam' => 'can-roam',
        'logRotator' => 'log-rotator',
        'artifactDaysToKeep' => 'artifact-days-to-keep',
        'hudson.tasks.Mailer' => 'mailer',
        'dontNotifyEveryUnstableBuild' => 'dont-notify-every-unstable-build',
        'hudson.triggers.SCMTrigger' => 'scm-trigger'
    };
}

sub main {
    my $args = shift || {'xml_dir'=>$ENV{'JJBC_JOB_DIR'}, 'yaml_dir'=>$ENV{'JJBC_YAML_DIR'}};
    my $driver = CI::Job::Driver->new($args);
    $driver->create_yaml_jobs;
}

main() unless caller;

no Moose;

my $root;

BEGIN {
    use File::Basename ();
    use File::Spec     ();
    $root = File::Basename::dirname(__FILE__);
    $root = File::Spec->rel2abs($root);
    unshift @INC, "$root/../../lib";
}

1;
