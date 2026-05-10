#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <stdio.h>
#include <iostream>
#include <fstream>
#include <cstdint>
#include <cstdlib>
#include <chrono>
//Paralel
// Kernel=function on the GPU(not related to OS)Edit:third cousin of the cat
// This one in particular sorts by collums(0's get insterted form the back and 1's form the front)
__global__ void radix_sort(uint32_t* data, uint32_t cols, uint16_t rows, uint32_t* bucket) {
   const int tid = blockDim.x * blockIdx.x + threadIdx.x;
   uint16_t count1 = rows, count2 = rows;
   uint16_t count3, count4;

   if (tid < cols) {
       for (uint8_t pos = 0; pos < 32; pos++) {
           if (pos % 2 == 0) {
               count3 = 0, count4 = rows - 1;
               for (uint16_t i = 0; i < count1; i++) {
                   if ((data[tid + i * cols] & (1 << pos)) == 0) {
                       bucket[tid + count3 * cols] = data[tid + i * cols];
                       count3 += 1;
                   }
                   else {
                       bucket[tid + count4 * cols] = data[tid + i * cols];
                       count4 -= 1;
                   }
               }
               for (uint16_t i = rows - 1; i > count2; i--) {
                   if ((data[tid + i * cols] & (1 << pos)) == 0) {
                       bucket[tid + count3 * cols] = data[tid + i * cols];
                       count3 += 1;
                   }
                   else {
                       bucket[tid + count4 * cols] = data[tid + i * cols];
                       count4 -= 1;
                   }
               }
           }
           else {
               count1 = 0, count2 = rows - 1;
               for (uint16_t i = 0; i < count3; i++) {
                   if ((bucket[tid + i * cols] & (1 << pos)) == 0) {
                       data[tid + count1 * cols] = bucket[tid + i * cols];
                       count1 += 1;
                   }
                   else {
                       data[tid + (count2 * cols)] = bucket[tid + i * cols];
                       count2 -= 1;
                   }
               }
               for (uint16_t i = rows - 1; i > count4; i--) {
                   if ((bucket[tid + i * cols] & (1 << pos)) == 0) {
                       data[tid + count1 * cols] = bucket[tid + i * cols];
                       count1 += 1;
                   }
                   else {
                       data[tid + (count2 * cols)] = bucket[tid + i * cols];
                       count2 -= 1;
                   }
               }
           }
       }
       for (uint16_t i = 0; i < count1; i++) bucket[tid + i * cols] = data[tid + i * cols];
       for (uint16_t i = count2 + 1; i < rows; i++) bucket[tid + i * cols] = data[tid + (count2 + rows - i) * cols];
   }
}


void checkCudaError(cudaError_t err, const char* msg) {
   if (err != cudaSuccess) {
       std::cerr << "CUDA Error: " << msg << " - " << cudaGetErrorString(err) << std::endl;
       exit(EXIT_FAILURE);
   }
}

void initcvs()
{
   std::ofstream file("output.csv", std::ios::trunc);
   if (file.is_open()) {
       file << "Algorithm,Size,Duration(ms)\n";
       file.close();
   }
}

void CWSwrite(const size_t size,std::chrono::microseconds duration,int algorithm=1)
{
   std::ofstream file("output.csv", std::ios::app);
   if (!file.is_open())
   {
       std::cout << "erros opening the file";
       return;
   }
   if (algorithm == 1)
   {
       file << "Bitwise Radix Sort"<<","<< size <<","<< duration.count() / 1000.0 << "\n";
   }
}
int main() {
   
   const uint32_t cols = 500000;      // Number of threads per row
   const uint16_t rows = 20000;     // Number of elements per column
   const size_t total_elements = cols * rows;
   int r;
   std::cout << "How many runs?: ";
   std::cin >> r;

   initcvs();
   

   for (int j = 0;j < r;j++)
   {   //Alocate host memory

       uint32_t* h_data = new uint32_t[total_elements];
       uint32_t* h_bucket = new uint32_t[total_elements];
       uint32_t* h_result = new uint32_t[total_elements];

       std::srand(std::time(nullptr));
       //"Original data (column-major layout)
       for (uint16_t row = 0; row < rows; row++) {
           for (uint32_t col = 0; col < cols; col++) {
               h_data[col + row * cols] = std::rand() % 1000; // Random numbers 0-999

           }

       }

       
       uint32_t* d_data = nullptr;
       uint32_t* d_bucket = nullptr;

       checkCudaError(cudaMalloc(&d_data, total_elements * sizeof(uint32_t)), "cudaMalloc d_data");
       checkCudaError(cudaMalloc(&d_bucket, total_elements * sizeof(uint32_t)), "cudaMalloc d_bucket");


       checkCudaError(cudaMemcpy(d_data, h_data, total_elements * sizeof(uint32_t), cudaMemcpyHostToDevice),
           "cudaMemcpy h_data -> d_data");

       // Kernel launch configuration
       // Each thread processes one column independently
       const int threadsPerBlock = 256;
       const int blocksPerGrid = (cols + threadsPerBlock - 1) / threadsPerBlock;


       //timer
       auto start = std::chrono::high_resolution_clock::now();

       radix_sort << <blocksPerGrid, threadsPerBlock >> > (d_data, cols, rows, d_bucket);

       auto end = std::chrono::high_resolution_clock::now();
       auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);



       checkCudaError(cudaGetLastError(), "Kernel launch");


       checkCudaError(cudaDeviceSynchronize(), "Kernel execution");


       checkCudaError(cudaMemcpy(h_result, d_bucket, total_elements * sizeof(uint32_t), cudaMemcpyDeviceToHost),
           "cudaMemcpy d_bucket -> h_result");

       CWSwrite(total_elements, duration);






       delete[] h_data;
       delete[] h_bucket;
       delete[] h_result;
       cudaFree(d_data);
       cudaFree(d_bucket);
   }

   return 0;
}