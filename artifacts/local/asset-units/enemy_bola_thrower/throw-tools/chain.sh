#!/bin/bash
# usage: chain.sh <state>   prints the --call flags (one per line) that stage a throw state
T=/root/Game/Spawn_bola_thrower
B=/root/Game/Player/RigidBall
D=0.0111111111
state=$1
q() { python3 -c "print(repr(round($1,6)))"; }
echo "--call=$T:set:0:[\"attack_range\",0.0]"
echo "--call=$T:set:0:[\"walk_speed\",0.0]"
echo "--call=$T:set_indexed:0:[\"global_position:x\",80.0]"
echo "--call=$T:set_indexed:0:[\"global_position:y\",${THY:-30.9}]"
echo "--call=$T:set_indexed:0:[\"global_position:z\",-100.0]"
echo "--call=$T:set_indexed:0:[\"velocity:y\",0.0]"
echo "--call=$B:set_indexed:0:[\"global_position:x\",80.0]"
echo "--call=$B:set_indexed:0:[\"global_position:y\",${BAY:-31.2}]"
echo "--call=$B:set_indexed:0:[\"global_position:z\",-92.0]"
echo "--call=$B:set_indexed:0:[\"linear_velocity:x\",0.0]"
echo "--call=$B:set_indexed:0:[\"linear_velocity:y\",0.0]"
echo "--call=$B:set_indexed:90:[\"linear_velocity:z\",0.0]"
echo "--call=$B:set:2:[\"freeze\",true]"
echo "--call=$T:set:1:[\"attack_range\",30.0]"
case $state in
  wind25) echo "--call=$T:set:1:[\"_t\",$(q 0.125-$D)]";;
  wind60) echo "--call=$T:set:1:[\"_t\",$(q 0.3-$D)]";;
  wind95) echo "--call=$T:set:1:[\"_t\",$(q 0.475-$D)]";;
  rel30|rel70|rel95|land)
    echo "--call=$T:set:1:[\"_t\",0.5]"
    case $state in
      rel30) echo "--call=$T:set:1:[\"_t\",$(q 1.3*0.3-$D)]";;
      rel95) echo "--call=$T:set:1:[\"_t\",$(q 1.3*0.95-$D)]";;
      rel70) echo "--call=$T:set:1:[\"_t\",$(q 1.3*0.7-$D)]";;
      land) echo "--call=$T:set:1:[\"_t\",$(q 1.3+0.05-$D)]";;
    esac;;
esac
