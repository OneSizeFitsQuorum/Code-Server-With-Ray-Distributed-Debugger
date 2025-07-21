import ray

@ray.remote
def f(x):
    print(x)
    breakpoint()
    return x * x