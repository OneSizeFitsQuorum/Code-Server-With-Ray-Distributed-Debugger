import ray

ray.init()

from dependency.dependency import f

futures = [f.remote(i) for i in range(4)]

breakpoint()
print(ray.get(futures)) # [0, 1, 4, 9]