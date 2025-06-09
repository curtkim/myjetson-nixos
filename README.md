## 목표
- cuda를 사용하는 application을 실행해서 cuda설치를 확인한다.


## 문제
- torch : 실패
- llama-cpp : cmake가 참조하는 cuda target이 없음
  (cuda version문제이지 않을까? jetpack-nixos는 cuda 11을 제공하는데, llama-cpp는 12를 요구해서?)
- ollama-cuda : 실패, CUDA:cuda_driver 를 찾지 못해 에러가 발생


## 미래에 해결해야 하는것
- xavier에서 build하지 않고, x86에서 원격빌드하게 수정

