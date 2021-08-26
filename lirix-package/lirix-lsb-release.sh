#!/bin/bash
lsbver=$(head -n 1 /etc/lsb-release)
echo $lsbver > /etc/lsb-release
echo "DISTRIB_ID=Lirix" >> /etc/lsb-release
echo "DISTRIB_RELEASE=\"$(cat /etc/lirix-release | awk '{print $2}'), rolling\"" >> /etc/lsb-release
echo "DISTRIB_DESCRIPTION=\"Lirix $(cat /etc/lirix-release | awk '{print $2}')\"" >> /etc/lsb-release
echo "DISTRIB_CODENAME=$(cat /etc/lirix-release | awk '{print $2}')" >> /etc/lsb-release