#!/bin/bash -xe


export USER=app

curl -fsSL https://install.perlbrew.pl | bash;
echo 'source /home/app/perl5/perlbrew/etc/bashrc' >> /home/app/.bashrc;

source /home/app/perl5/perlbrew/etc/bashrc

perlbrew install -n -j 8 perl-5.34.1
perlbrew install-cpanm
perlbrew switch perl-5.34.1
