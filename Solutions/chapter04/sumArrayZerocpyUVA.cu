#include "../common/common.h"
#include <cuda_runtime.h>
#include <stdio.h>

/*
 * This example demonstrates the use of zero-copy memory with CUDA's unified
 * virtual addressing (UVA). UVA automatically resolves any device or host
 * pointer on the GPU to its correct location in host or device memory. This
 * removes the need to use cudaMemcpy or cudaHostGetDevicePointer, as well as
 * removing programmer burden in keeping track of duplicate pointers which point
 * to the same physical data.
 *
 * This example compares performing a vector addition with and without UVA.
 */


void checkResult(float *hostRef, float *gpuRef, const int N)
{
    double epsilon = 1.0E-8;

    for (int i = 0; i < N; i++)
    {
        if (abs(hostRef[i] - gpuRef[i]) > epsilon)
        {
            printf("Arrays do not match!\n");
            printf("host %5.2f gpu %5.2f at current %d\n", hostRef[i],
                    gpuRef[i], i);
            break;
        }
    }

    return;
}

void initialData(float *ip, int size)
{
    int i;

    for (i = 0; i < size; i++)
    {
        ip[i] = (float)( rand() & 0xFF ) / 10.0f;
    }

    return;
}

void sumArraysOnHost(float *A, float *B, float *C, const int N)
{
    for (int idx = 0; idx < N; idx++)
    {
        C[idx] = A[idx] + B[idx];
    }
}

__global__ void sumArrays(float *A, float *B, float *C, const int N)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;

    if (i < N) C[i] = A[i] + B[i];
}

__global__ void sumArraysZeroCopy(float *A, float *B, float *C, const int N)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;

    if (i < N) C[i] = A[i] + B[i];
}

__global__ void sumArraysZeroCopyWithUVA(float *A, float *B, float *C,
        const int N)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;

    if (i < N) C[i] = A[i] + B[i];
}

int main(int argc, char **argv)
{
    // set up device
    int dev = 0;
    CHECK(cudaSetDevice(dev));

    // get device properties
    cudaDeviceProp deviceProp;
    CHECK(cudaGetDeviceProperties(&deviceProp, dev));

    // check if support mapped memory
    if (!deviceProp.canMapHostMemory)
    {
        printf("Device %d does not support mapping CPU host memory!\n", dev);
        CHECK(cudaDeviceReset());
        exit(EXIT_SUCCESS);
    }

    printf("Using Device %d: %s ", dev, deviceProp.name);

    // set up data size of vectors
    int ipower = 24;

    if (argc > 1) ipower = atoi(argv[1]);

    int nElem = 1 << ipower;
    size_t nBytes = nElem * sizeof(float);

    if (ipower < 18)
    {
        printf("Vector size %d power %d  nbytes  %3.0f KB\n", nElem, ipower,
               (float)nBytes / (1024.0f));
    }
    else
    {
        printf("Vector size %d power %d  nbytes  %3.0f MB\n", nElem, ipower,
               (float)nBytes / (1024.0f * 1024.0f));
    }

    // part 1: using device memory
    // malloc host memory
    float *h_A, *h_B, *hostRef, *gpuRef;
    h_A     = (float *)malloc(nBytes);
    h_B     = (float *)malloc(nBytes);
    hostRef = (float *)malloc(nBytes);
    gpuRef  = (float *)malloc(nBytes);

    // initialize data at host side
    initialData(h_A, nElem);
    initialData(h_B, nElem);
    memset(hostRef, 0, nBytes);
    memset(gpuRef,  0, nBytes);

    // add vector at host side for result checks
    sumArraysOnHost(h_A, h_B, hostRef, nElem);

    // malloc device global memory
    float *d_A, *d_B, *d_C;
    CHECK(cudaMalloc((float**)&d_A, nBytes));
    CHECK(cudaMalloc((float**)&d_B, nBytes));
    CHECK(cudaMalloc((float**)&d_C, nBytes));

    // transfer data from host to device
    CHECK(cudaMemcpy(d_A, h_A, nBytes, cudaMemcpyHostToDevice));
    CHECK(cudaMemcpy(d_B, h_B, nBytes, cudaMemcpyHostToDevice));

    // set up execution configuration
    int iLen = 512;
    dim3 block (iLen);
    dim3 grid  ((nElem + block.x - 1) / block.x);

    double start = seconds();
    sumArrays<<<grid, block>>>(d_A, d_B, d_C, nElem);
    CHECK(cudaDeviceSynchronize());
    double elapsed = seconds() - start;
    printf("sumArrays, elapsed = %f s\n", elapsed);

    // copy kernel result back to host side
    CHECK(cudaMemcpy(gpuRef, d_C, nBytes, cudaMemcpyDeviceToHost));

    // check device results
    checkResult(hostRef, gpuRef, nElem);

    // free device global memory
    CHECK(cudaFree(d_A));
    CHECK(cudaFree(d_B));

    // free host memory
    free(h_A);
    free(h_B);

    // part 2: using zerocopy memory for array A and B
    // allocate zerocpy memory
    CHECK(cudaHostAlloc((void **)&h_A, nBytes, cudaHostAllocMapped));
    CHECK(cudaHostAlloc((void **)&h_B, nBytes, cudaHostAllocMapped));

    // initialize data at host side
    initialData(h_A, nElem);
    initialData(h_B, nElem);
    memset(hostRef, 0, nBytes);
    memset(gpuRef,  0, nBytes);

    // pass the pointer to device
    CHECK(cudaHostGetDevicePointer((void **)&d_A, (void *)h_A, 0));
    CHECK(cudaHostGetDevicePointer((void **)&d_B, (void *)h_B, 0));

    // add at host side for result checks
    sumArraysOnHost(h_A, h_B, hostRef, nElem);

    // execute kernel with zero copy memory
    start = seconds();
    sumArraysZeroCopy<<<grid, block>>>(d_A, d_B, d_C, nElem);
    CHECK(cudaDeviceSynchronize());
    elapsed = seconds() - start;
    printf("sumArraysZeroCopy, elapsed = %f s\n", elapsed);

    // copy kernel result back to host side
    CHECK(cudaMemcpy(gpuRef, d_C, nBytes, cudaMemcpyDeviceToHost));

    // check device results
    checkResult(hostRef, gpuRef, nElem);

    memset(gpuRef,  0, nBytes);

    // execute kernel with zero copy memory
    start = seconds();
    sumArraysZeroCopyWithUVA<<<grid, block>>>(h_A, h_B, d_C, nElem);
    CHECK(cudaDeviceSynchronize());
    elapsed = seconds() - start;
    printf("sumArraysZeroCopy w/ UVA, elapsed = %f s\n", elapsed);

    // copy kernel result back to host side
    CHECK(cudaMemcpy(gpuRef, d_C, nBytes, cudaMemcpyDeviceToHost));

    // check device results
    checkResult(hostRef, gpuRef, nElem);

    // free  memory
    CHECK(cudaFree(d_C));
    CHECK(cudaFreeHost(h_A));
    CHECK(cudaFreeHost(h_B));

    free(hostRef);
    free(gpuRef);

    // reset device
    CHECK(cudaDeviceReset());
    return EXIT_SUCCESS;
}
