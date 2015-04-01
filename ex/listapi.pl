#!/usr/bin/perl

use Mojo::Util 'slurp';
use Data::Dumper 'Dumper';
use Mojo::Cloudstack;

my $api_key = slurp("/home/holger/.mojo_cloudstack/api_key");
chomp $api_key;
my $secret_key = slurp("/home/holger/.mojo_cloudstack/secret_key");
chomp $secret_key;

my $cs = Mojo::Cloudstack->new(
  host       => "172.29.0.12",
  path       => "/client/api",
  port       => "443",
  scheme     => "https",
  api_key    => $api_key,
  secret_key => $secret_key,
);

my $zones = $cs->listZones;
my $zone1 = $zones->first;

my $sos = $cs->listServiceOfferings(id => "44741d1a-242d-43dc-8dad-82af1d549866");
my $so = $sos->first;

my $templates = $cs->listTemplates(
  templatefilter => 'featured',
  id => 'be8251d3-4d64-47fe-8ab2-4d77c0d6b068'
);
my $t = $templates->first;


warn Dumper $zone1, $so, $templates;
warn Dumper $zone1->name, $so->name, $t->name ;

my $vm = $cs->deployVirtualMachine(
  serviceofferingid => $so->id,
  templateid => $t->id,
  zoneid => $zone1->id,
);
warn Dumper $vm;
