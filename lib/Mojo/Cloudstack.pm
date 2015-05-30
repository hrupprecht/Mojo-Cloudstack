package Mojo::Cloudstack;

use Mojo::Base 'Mojo::UserAgent';
use Mojo::Parameters;
use Mojo::URL;
use Mojo::UserAgent;
use Mojo::JSON 'j';
use Mojo::Util 'slurp';
use Mojo::Collection 'c';
use Mojo::Cloudstack::Base;
use Mojo::Cloudstack::Api;
use Digest::HMAC_SHA1 qw(hmac_sha1 hmac_sha1_hex);
use MIME::Base64;
use URI::Encode 'uri_encode';
use File::HomeDir;
use Data::Dumper 'Dumper';

has 'host'        => "localhost";
has 'path'        => "/client/api";
has 'port'        => "8080";
has 'scheme'      => "https";
has 'api_key'     => "";
has 'secret_key'  => "";
has 'responsetypes' => '';
has 'api_cache'   => sub {
  my $self = shift;
  $self->_load_api_cache;
  $self->__build_responsetypes;
};

our $VERSION = '0.05';
our $AUTOLOAD;

chomp(our $user = `whoami`);
our $cf = File::HomeDir->users_home($user) . "/.cloudmojo/api.json";

sub _build_request {
  my ($self, $params) = @_;
  my $baseurl = sprintf ("%s://%s:%s%s?", $self->scheme, $self->host, $self->port, $self->path);
  $params->{ apiKey }   = $self->api_key;
  $params->{ response } = 'json';
  my $secret_key = $self->secret_key;

  my $req_params = Mojo::Parameters->new();
  foreach my $p (sort keys %$params) {
    $req_params->param($p => uri_encode($params->{ $p }));
  }
  my $params_str = lc ($req_params->to_string);
  my $digest = hmac_sha1($params_str, $secret_key);
  my $base64_encoded = encode_base64($digest);
  chomp ($base64_encoded);

  my $uri_encoded = uri_encode($base64_encoded,1);
  my $url = Mojo::URL->new($baseurl);
  $url->query($req_params->to_string);

  return $url->to_string . '&signature='.$uri_encoded;

}

sub AUTOLOAD {
  my $self = shift;
  (my $command = $AUTOLOAD) =~ s/.*:://;
  my %params = @_;
  $params{command} = $command;
  my $req = $self->_build_request(\%params);
  my $res = $self->get($req)->res;
  my $items = $res->json;
  #warn Dumper 'ITEMS', $items;
  die sprintf("Could not get response for %s %s %s", $req,  $res->code, $res->message) unless $items;
  my $responsetype = (keys %$items)[0];

  if($responsetype =~ /^(login|activate|add|archive|assign|associate|attach|authorize|change|configure|copy|create|delete|deploy|destroy|detach|disable|disassociate|enable|error|expunge|extract|get|list|lock|migrate|query|reboot|recover|register|remove|replace|reset|resize|restart|restore|revert|revoke|scale|start|stop|suspend|update|upload)(.*)(response)$/){
    my ($otype, $oname, $oresponse) = ($1, $2, $3);
    $items->{$responsetype}{_cs} = $self unless $oname eq 'apis';
    if($oname eq 'apis'){
      $self->__write_api_cache($items);
      return $items;
    } elsif($otype eq 'list'){
      if($oname =~ /(s)$/){
        $oname =~ s/$1$//;
      }
      return c(
        map {
          $_->{_cs} = $self;
          Mojo::Cloudstack::Base->new('Mojo::Cloudstack::' . ucfirst($oname),$_);
        } @{$items->{$responsetype}{$oname}}
      );
    } elsif($otype eq 'query'){
      return  Mojo::Cloudstack::Base->new('Mojo::Cloudstack::AsyncJobResult', $items->{$responsetype});
    } elsif(exists $items->{$responsetype}{errorcode}){
      return  Mojo::Cloudstack::Base->new('Mojo::Cloudstack::Error', $items->{$responsetype});
    } elsif($otype =~ /^log(in|out)$/){
      return  Mojo::Cloudstack::Base->new('Mojo::Cloudstack::' . ucfirst($&), $items->{$responsetype});
    } else {
      return  Mojo::Cloudstack::Base->new('Mojo::Cloudstack::' . (exists $items->{$responsetype}{jobid}
        ? 'AsyncJobRequest'
        : ucfirst($oname)), $items->{$responsetype});
    }
  } else {
    die "unknown response type $responsetype for reqest \n$req";
  }

}

sub sync {
  return shift->_load_api_cache(1);
}

sub _load_api_cache {
  my ($self, $force) = @_;
  $self->api_cache($self->__build_api_json($force))
    and return $self->api_cache
      if ($force or (not -f $cf));
  #TODO File::ShareDir

  $self->api_cache(j(slurp $cf)) if -f $cf;
  return $self->api_cache;
}

sub __build_responsetypes {
  my ($self) = @_;
  my $apis = $self->api_cache;
  my %responsetypes = map { (split(/[A-Z]/,$_->{name},2))[0] => 1  }
    @{ $apis->{listapisresponse}{api} };
  $responsetypes{error} = 1;
  $self->responsetypes(join('|', sort keys %responsetypes));
  die $self->responsetypes;
}

sub __build_api_json {
  my ($self, $force) = @_;
  my $apis = $self->listApis;
  $self->__write_api_cache($apis, $force);
  return $apis;
}

sub __write_api_cache {
  my($self, $apis, $force) = @_;
  my $cachedir = File::HomeDir->users_home($user) . "/.cloudmojo";
  mkdir $cachedir unless -d $cachedir;
  my $cachefile = "$cachedir/api.json";
  unlink $cachefile if $force;
  unless (-f $cachefile){
    open my $cf, ">$cachefile";
    print $cf j($apis);
    close $cf;
  }
  return $apis;

}

1;

__END__

=pod

=head1 NAME

Mojo::Cloudstack

=head1 DESCRIPTION

Generic Class for Cloudstack API calls
The goal is to have blessed classes generated by AUTOLOAD, which are replaced
step by step by 'real' classes when enhanced functionality is needed.


=head1 SYNOPSIS

  use Mojo::Cloudstack;

=head1 METHODS

=head2 new

  my $cs = Mojo::Cloudstack->new(
    host       => "cloustack.local",
    path       => "/client/api",
    port       => "443",
    scheme     => "https",
    api_key    => $api_key,
    secret_key => $secret_key,
  );

  my $vmreq = $cs->deployVirtualMachine(
    serviceofferingid => $so->id,
    templateid => $t->id,
    zoneid => $zone1->id,
    projectid => $project_id,
  );

=head2 sync

Sync possible API calls against Cloudstack with your account
dependend on your permisions.

  $cs->sync;

=head2 _build_request

  my $params = Mojo::Parameters->new('command=listUsers&response=json');
  $params->append(apiKey => $cs->api_key);
  my $req = $cs->_build_request($params->to_hash)

=head2 api_key

API Key from Cloudstack

=head2  host

Host to connect to

=head2 path

URL path to API

=head2 port

Port to connect to

=head2 scheme

URL scheme http | https

=head2 secret_key

Secret Key from Cloudstack

=cut
