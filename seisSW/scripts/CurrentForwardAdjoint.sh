#!/bin/bash

[[ -n "${0}" ]] || { echo -e "\n### Usage ###\n./CurrentForwardAdjoint iter\n"; exit 0 ; }
 
# pass parameter files
source parameter

# local id (from 0 to $ntasks-1)
if [ $system == 'slurm' ]; then
    iproc=$SLURM_PROCID  
elif [ $system == 'pbs' ]; then
    iproc=$PBS_VNODENUM
fi

IPROC_WORKING_DIR=$( seq --format="$WORKING_DIR/%06.f/" $iproc $iproc )  
IPROC_DATA_DIR=$( seq --format="$DATA_DIR/%06.f/" $iproc $iproc )

mkdir -p $IPROC_WORKING_DIR

cd $IPROC_WORKING_DIR

# echo " link current model ... "
   cp $current_velocity_file ./DATA/model_velocity.dat
   if $attenuation; then
   cp $curent_attenuation_file ./DATA/model_attenuation.dat
   fi
   if $anisotropy; then
   cp $current_anisotropy_file ./DATA/model_anisotropy.dat
   fi
   ./bin/prepare_model.exe

##echo " edit 'Par_file' "
   FILE="./DATA/Par_file"
   sed -e "s#^SIMULATION_TYPE.*#SIMULATION_TYPE = 1 #g"  $FILE > temp; mv temp $FILE
   sed -e "s#^SAVE_FORWARD.*#SAVE_FORWARD = .true. #g"  $FILE > temp; mv temp $FILE
   sed -e "s#^SU_FORMAT.*#SU_FORMAT = .true.#g"  $FILE > temp; mv temp $FILE

   # cleans output files
   rm -rf ./OUTPUT_FILES/*
   ##### stores setup
   cp ./DATA/Par_file ./OUTPUT_FILES/
   cp ./DATA/SOURCE ./OUTPUT_FILES/

#STARTTIME=$(date +%s)

   ##### forward simulation (data) #####
   ./bin/xmeshfem2D > OUTPUT_FILES/output_mesher.txt
   ./bin/xspecfem2D > OUTPUT_FILES/output_solver.txt

#ENDTIME=$(date +%s)
#Ttaken=$(($ENDTIME - $STARTTIME))
#echo "$(($Ttaken / 60)) minutes and $(($Ttaken % 60)) seconds elapsed for forward simulation."

# save 
cp OUTPUT_FILES/*_file_single.su           DATA_syn/

# process & stores output
  if ${XCOMP}; then
  sh ./SU_process/syn_process.sh DATA_syn/Ux_file_single.su DATA_syn/Ux_file_single_processed.su
  fi
  if ${YCOMP}; then
  sh ./SU_process/syn_process.sh DATA_syn/Uy_file_single.su DATA_syn/Uy_file_single_processed.su
  fi
  if ${ZCOMP}; then
  sh ./SU_process/syn_process.sh DATA_syn/Uz_file_single.su DATA_syn/Uz_file_single_processed.su
  fi
  if ${PCOMP}; then
  sh ./SU_process/syn_process.sh DATA_syn/Up_file_single.su DATA_syn/Up_file_single_processed.su
  fi

#echo "finish forward simulation for current model"

## adjoint source
#STARTTIME=$(date +%s)
  # save adjoint source or not 
      compute_adjoint=.true.
     ./bin/misfit_adjoint.exe $compute_adjoint 

if $src_est; then 
   cp DATA/src.txt DATA/wavelet.txt
fi 

if $DISPLAY_DETAILS; then
   mkdir -p $SUBMIT_DIR/$SUBMIT_RESULT/$iproc
   cp DATA_syn/*.adj $SUBMIT_DIR/$SUBMIT_RESULT/$iproc/
fi


#ENDTIME=$(date +%s)
#Ttaken=$(($ENDTIME - $STARTTIME))
#echo "$(($Ttaken / 60)) minutes and $(($Ttaken % 60)) seconds elapsed for adjoint source evaluation."
## adjoint simulation
#STARTTIME=$(date +%s)
##### edit 'Par_file' #####
   FILE="./DATA/Par_file"
   sed -e "s#^SIMULATION_TYPE.*#SIMULATION_TYPE = 3 #g"  $FILE > temp; mv temp $FILE
   sed -e "s#^SAVE_FORWARD.*#SAVE_FORWARD = .false. #g"  $FILE > temp; mv temp $FILE
   if ${SU_adjoint}; then
   sed -e "s#^SU_FORMAT.*#SU_FORMAT = .true.#g"  $FILE > temp; mv temp $FILE
   else
   sed -e "s#^SU_FORMAT.*#SU_FORMAT = .false.#g"  $FILE > temp; mv temp $FILE 
   fi
  
##### adjoint simulation (data) #####
   ./bin/xmeshfem2D > OUTPUT_FILES/output_mesher.txt
   ./bin/xspecfem2D > OUTPUT_FILES/output_adjoint.txt
#echo "finish adjoint simulation $iproc "


#ENDTIME=$(date +%s)
#Ttaken=$(($ENDTIME - $STARTTIME))
#echo "$(($Ttaken / 60)) minutes and $(($Ttaken % 60)) seconds elapsed for adjoint simulation."

