use strict;
use warnings;
use Test::More;
use Data::Dumper 'Dumper';
use Mojo::Util 'slurp';
use Mojo::Cloudstack;

my $conf = do 'b_i_t-cloud.conf';
my $config = $conf->{cloudstack};
my $api_key = slurp("/home/holger/.mojo_cloudstack/api_key");
chomp $api_key;
my $secret_key = slurp("/home/holger/.mojo_cloudstack/secret_key");
chomp $secret_key;

my $cs = Mojo::Cloudstack->new(
  host       => "172.29.0.10",
  path       => "/client/api",
  port       => "443",
  scheme     => "https",
  api_key    => $api_key,
  secret_key => $secret_key,
);

my $rllist = $cs->listResourceLimits(
  #projectid => '22'
  #account => 'b00339',
  projectid => '6f3458ea-15cb-49c0-aca8-8b16ac309a8c',
  #6 - Network. Number of networks an account can own
  resourcetype => 6,
  listall => 1,
);

my $u = $cs->updateResourceLimit(
  projectid => '6f3458ea-15cb-49c0-aca8-8b16ac309a8c',
  resourcetype => 6,
  max => 2,
);

my $v = $cs->listVirtualMachines(
  projectid => '6f3458ea-15cb-49c0-aca8-8b16ac309a8c',
);

diag Dumper $rllist, $u, $v;

