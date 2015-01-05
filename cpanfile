requires "Carp" => "0";
requires "Moose" => "0";
requires "MooseX::StrictConstructor" => "0";
requires "MooseX::Types::Moose" => "0";
requires "Mozilla::CA" => "0";
requires "URI" => "0";
requires "WWW::Mechanize" => "0";
requires "strict" => "0";
requires "warnings" => "0";

on 'build' => sub {
  requires "Module::Build" => "0.28";
};

on 'test' => sub {
  requires "DDP" => "0";
  requires "Plack::Test::Agent" => "0";
  requires "Test::Fatal" => "0";
  requires "Test::Most" => "0";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
  requires "Module::Build" => "0.28";
};

on 'develop' => sub {
  requires "Pod::Coverage::TrustPod" => "0";
  requires "Test::CPAN::Changes" => "0.19";
  requires "Test::Pod::Coverage" => "1.08";
  requires "Test::Spelling" => "0.12";
  requires "Test::Synopsis" => "0";
};
