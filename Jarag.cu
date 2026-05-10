#include <vector>
#include <algorithm>
#include <cmath>
#include <iostream>
#include<fstream>
#include <ctime>
#include<chrono>
#include"cuda_runtime.h"
#include "device_launch_parameters.h"


__global__ void BitonicSort(int p, int* fat_arr)
{
    for (int d = 2; d <= p; d <<= 1)
    {
        for (int i = d / 2; i > 0; i >>= 1)
        {
            int tid = threadIdx.x + blockIdx.x * blockDim.x;

            
              
                int tidxorj = i ^ tid;
                if (tidxorj > tid)
                {
                    if ((tid & d) == 0)  // Ascending block
                    {
                        if (fat_arr[tid] > fat_arr[tidxorj])
                            fat_arr[tid] += fat_arr[tidxorj];
                            fat_arr[tidxorj] = fat_arr[tid]- fat_arr[tidxorj];
                            fat_arr[tid] -= fat_arr[tidxorj];
                            
                    }
                    else  // Descending block
                    {
                        if (fat_arr[tid] < fat_arr[tidxorj])
                            fat_arr[tid] += fat_arr[tidxorj];
                            fat_arr[tidxorj] = fat_arr[tid] - fat_arr[tidxorj];
                            fat_arr[tid] -= fat_arr[tidxorj];
                    }
                }
           
            
            
        }
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

void CWSwrite(const size_t size, std::chrono::microseconds duration, int algorithm = 1)
{
    std::ofstream file("output.csv", std::ios::app);
    if (!file.is_open())
    {
        std::cout << "erros opening the file";
        return;
    }
    if (algorithm == 1)
    {
        file << "Bitwise Radix Sort" << "," << size << "," << duration.count() / 1000.0 << "\n";
    }
    else
        file << "Bitonic Sort" << "," << size << "," << duration.count() / 1000.0 << "\n";
}

int main()
{
    srand(time(0));  
    initcvs();

    int n,r, p = 1;
    std::cout << "Small numbers please!\n";
    std::cin >> n;
    std::cout << "Beeg runs only: ";
    std::cin >> r;

    
    
    for (int j = 0;j < r;j++)
    {
        int* arr = new int[n];
        for (int i = 0; i < n; i++)
        {
            arr[i] = rand() % 100;
        }



        while (p < n) p <<= 1;
        int* fat_arr = new int[p];
        for (int i = 0; i < n; i++)
            fat_arr[i] = arr[i];
        for (int i = n; i < p; i++)
            fat_arr[i] = INT_MAX;

        ///GPU alocations
        int* d_fat_arr = nullptr;
       
        int threadsPerBlock = 256;
        int blocksPerGrid = (p + threadsPerBlock - 1) / threadsPerBlock;
        cudaMallocManaged(&d_fat_arr, sizeof(int)*p);

        auto start = std::chrono::high_resolution_clock::now();
        
        BitonicSort << <blocksPerGrid, threadsPerBlock >> > (p,d_fat_arr);

        auto end = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);

        
        CWSwrite(n, duration, 2);

        delete[] arr;
        delete[] fat_arr;
    }

    return 0;
}