use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => 'Catalyst::Plugin::XMLRPC',
    'VERSION_FROM' => 'XMLRPC.pm',
    'PREREQ_PM'    => { Catalyst => '5.01', RPC::XML => 1 }
);
