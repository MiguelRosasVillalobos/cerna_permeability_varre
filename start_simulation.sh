#Miguel Rosas

# Verifica si se proporciona la cantidad_simulaciones como argumento
if [ $# -eq 0 ]; then
	echo "Uso: $0 cantidad_simulaciones"
	exit 1
fi

# Obtiene la cantidad_simulaciones desde el primer argumento
cantidad_simulaciones=$1

Re1=10
Re2=50
Re3=90
Re4=130
Re5=170
Re6=210
Re7=250
Re8=290
Re9=330
Re10=370
Re11=410
Re12=450
Re13=490
Re14=530
Re15=570

# Valores de Reynolds a utilizar
valores_Re=("Re1" "Re2" "Re3" "Re4" "Re5" "Re6" "Re7" "Re8" "Re9" "Re10" "Re11" "Re12" "Re13" "Re14" "Re15")

# Leer valores desde el archivo parametros.txt
nu=$(grep -oP 'nu\s*=\s*\K[\d.+-]+' parametros.txt)
Ld=$(grep -oP 'Ld\s*=\s*\K[\d.+-]+' parametros.txt)

lc=$(grep -oP 'lc\s*=\s*\K[\d.+-]+' parametros.txt)
lcc=$(grep -oP 'lcc\s*=\s*\K[\d.+-]+' parametros.txt)
rd=$(grep -oP 'rd\s*=\s*\K[\d.+-]+' parametros.txt)
l1=$(grep -oP 'l1\s*=\s*\K[\d.+-]+' parametros.txt)
a=$(grep -oP 'a\s*=\s*\K[\d.+-]+' parametros.txt)
rp=$(grep -oP 'rp\s*=\s*\K[\d.+-]+' parametros.txt)
np=$(grep -oP 'np\s*=\s*\K[\d.+-]+' parametros.txt)

tf=$(grep -oP 'tf\s*=\s*\K[\d.+-]+' parametros.txt)
dt=$(grep -oP 'dt\s*=\s*\K[\d.+-]+' parametros.txt)
wi=$(grep -oP 'wi\s*=\s*\K[\d.+-]+' parametros.txt)

# Bucle para crear y mover carpetas, editar y genrar mallado
for ((i = 1; i <= $cantidad_simulaciones; i++)); do
	# Genera el nombre de la carpeta
	carpeta_caso_i="Case_$i"

	# Crea la carpeta del caso
	mkdir "$carpeta_caso_i"

	# Copia carpetas del caso dentro de las carpetasgeneradas
	cp -r "Case_0/0/" "$carpeta_caso_i/"
	cp -r "Case_0/constant/" "$carpeta_caso_i/"
	cp -r "Case_0/system/" "$carpeta_caso_i/"
	cp -r "Case_0/geometry_script/" "$carpeta_caso_i/"
	cp "Case_0/mesh.geo" "$carpeta_caso_i/"

	cd "$carpeta_caso_i/"

	# Reemplazar valores en sus respectivos archivos
	sed -i "s/\$nuu/$nu/g" ./0/U
	sed -i "s/\$nuu/$nu/g" ./constant/transportProperties
	sed -i "s/\$LL/$Ld/g" ./0/U

	sed -i "s/\$lccc/$lc/g" ./mesh.geo
	sed -i "s/\$rdd/$rd/g" ./mesh.geo
	sed -i "s/\$l11/$l1/g" ./mesh.geo
	sed -i "s/\$aa/$a/g" ./mesh.geo
	sed -i "s/\$lcccc/$lcc/g" ./mesh.geo

	sed -i "s/\$lccc/$lc/g" ./geometry_script/geometry.geo
	sed -i "s/\$rdd/$rd/g" ./geometry_script/geometry.geo
	sed -i "s/\$l11/$l1/g" ./geometry_script/geometry.geo
	sed -i "s/\$aa/$a/g" ./geometry_script/geometry.geo
	sed -i "s/\$rpp/$rp/g" ./geometry_script/geometry.geo

	sed -i "s/\$npp/$np/g" ./geometry_script/generator_point_process.py
	sed -i "s/\$rpp/$rp/g" ./geometry_script/generator_point_process.py
	sed -i "s/\$rdd/$rd/g" ./geometry_script/generator_point_process.py

	sed -i "s/\$wii/$wi/g" ./system/controlDict
	sed -i "s/\$dtt/$dt/g" ./system/controlDict
	sed -i "s/\$tff/$tf/g" ./system/controlDict

	cd "./geometry_script/"

	#Generar mallado gmsh
	python3 generator_point_process.py
	./generate.sh
	cd ..
	gmsh "./mesh.geo" -3

	#Genera mallado OpenFoam
	gmshToFoam "mesh.msh"

	# Utiliza grep para eliminar las líneas que contienen la palabra "physicalType" y sobrescribe el archivo original
	grep -v "physicalType" constant/polyMesh/boundary >constant/polyMesh/boundary.temp
	mv constant/polyMesh/boundary.temp constant/polyMesh/boundary

	# Reemplaza "patch" por "wall" en las líneas 35
	sed -i '23s/patch/wall/;' "constant/polyMesh/boundary"

	mkdir Case_0
	mv 0/ Case_0/
	mv constant/ Case_0/
	mv system/ Case_0/
	mv geometry_script/ Case_0/
	mv mesh.geo Case_0/
	mv mesh.msh Case_0/

	# Se inicia el cilclo para variar el valor de Reynolds
	for j in {0..14}; do

		# se crea carpeta del caso para el valor de Reynolds
		mkdir Case_${i}_${valores_Re[$j]}

		#se copian los archivops a la carpeta del caso
		cp -r Case_0/0/ Case_${i}_${valores_Re[$j]}/
		cp -r Case_0/constant/ Case_${i}_${valores_Re[$j]}/
		cp -r Case_0/system/ Case_${i}_${valores_Re[$j]}/

		#Se reemplaza el valor de Reynolds en el archivo 0/U
		sed -i "s/\$Ree/${!valores_Re[$j]}/g" Case_${i}_${valores_Re[$j]}/0/U

		cd Case_${i}_${valores_Re[$j]}/

		decomposePar
		mpirun -np 6 icoFoam -parallel

		reconstructPar
		foamToVTK

		rm -rR processor*

		mv "constant/" ".."
		mv "0/" ".."
		mv "system/" ".."
		mv "VTK/" ".."

		cd ..

		rm -rR "Case_${i}_${valores_Re[$j]}/"

		# Crea la carpeta del caso
		mkdir "Case_${i}_${valores_Re[$j]}"

		mv "constant/" "Case_${i}_${valores_Re[$j]}/"
		mv "0/" "Case_${i}_${valores_Re[$j]}/"
		mv "system/" "Case_${i}_${valores_Re[$j]}/"
		mv "VTK/" "Case_${i}_${valores_Re[$j]}/"
	done
done

echo "Proceso completado."
