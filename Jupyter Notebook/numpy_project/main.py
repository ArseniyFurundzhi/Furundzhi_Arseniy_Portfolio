import matplotlib.pyplot as plt
import numpy as np

x = np.linspace(0, 4*np.pi, 2000)
y = (np.sin(5*x-10/3*np.pi))**4

plt.figure(figsize=(18, 4))

points = np.array([0,  np.pi, 2*np.pi,  3*np.pi, 4*np.pi, 5*np.pi])
labels = [r'$0$', r'$\pi$', r'$2\pi$', r'$3\pi$', r'$4\pi$', r'$5\pi$']
plt.xticks(points, labels)

plt.plot(x, y, color='deepskyblue')

plt.show()

