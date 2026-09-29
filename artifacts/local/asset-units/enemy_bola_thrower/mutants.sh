#!/bin/bash
G=/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64
F=src/combat/bola_thrower.gd
cp $F ../../scratchpad/c13/wired.gd
run() {
  $G --headless --path . -s res://tests/enemy_bola_thrower_asset_test.gd > ../../scratchpad/c13/mut-$1.log 2>&1
  echo "$1 exit=$? $(grep -c '^FAIL' ../../scratchpad/c13/mut-$1.log) FAIL lines: $(grep '^FAIL' ../../scratchpad/c13/mut-$1.log | head -3 | tr '\n' '|')"
  cp ../../scratchpad/c13/wired.gd $F
}
git show c782620:sketches/core-loop/$F > $F
run base
sed -i 's/^const FLIGHT := 1.3/const FLIGHT := 1.4/' $F
run flight
sed -i 's/^\t_bola.position = Vector3(0.0, CREW_HALF + 1.1, 0.0)\n\tadd_child/&/' $F
python3 - <<'PY'
p="src/combat/bola_thrower.gd"
s=open(p).read()
s=s.replace("\tadd_child(_bola)\n","\tadd_child(_bola)\n\tvar extra := MeshInstance3D.new()\n\textra.mesh = BoxMesh.new()\n\tadd_child(extra)\n",1)
open(p,"w").write(s)
PY
run extra_mesh
sed -i 's/vertex_color_use_as_albedo = true/vertex_color_use_as_albedo = true\n\tpainted.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA/' $F
run alpha
sed -i 's/body.set_surface_override_material(parts\["flash"\], _material)/body.set_surface_override_material(parts["flash"], Palette.solid(Palette.VERDIGRIS))/' $F
run paint
sed -i 's/_bola.rotation.y += lerpf(SPIN, WIND_SPIN, wind)/_bola.rotation.y += SPIN/' $F
run pose
git diff --stat -- $F | tail -1
