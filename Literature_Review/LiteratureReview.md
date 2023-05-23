# Literature Review

### Article 1: IntelliLight: A Reinforcement Learning Approach for Intelligent Traffic Light Control

#### Summary

This paper seems using the basic reinforcement learning method(Q learning) to get the best signal pattern, but they claim that they use the Deep RL which confuse me a lot.

They use SUMO([Simulation of Urban MObility](https://www.eclipse.org/sumo/)), which is a open source lib developmed by German, to simulate the urban traffic flow.

The result of the paper is good and shows that the using of real world data can make the model more reality relative.

The highlight of this paper, in my view, is the using of the memory palace and the phase gate. These method enhace the long memory of the agent model.

#### Reference

Wei, H., Zheng, G., Yao, H. and Li, Z. (2018). ‘IntelliLight: A Reinforcement Learning
Approach for Intelligent Traffic Light Control’. in  *Proceedings of the 24th
ACM SIGKDD International Conference on Knowledge Discovery & Data Mining* .
*KDD ’18: The 24th ACM SIGKDD International Conference on Knowledge Discovery
and Data Mining* , London United Kingdom: ACM, pp. 2496–2505. doi:
10.1145/3219819.3220096.

### Article 2: Self-organizing Traffic Lights: A Realistic Simulation

#### Summary

This paper is mentioned by the article 1 and I think this paper is quiet seems like my method - the ABM way.

In my opinion, the methodology of 'Self-organization' used in this paper is somewhat coincidental with the idea of ABM.

But the paper only consider the lenght of waiting cars and other factors to change the signal strategy. If a large number of waiting vehicles accumulate in front of the red light, the red light at that intersection changes to green.

To me, it seems clear that this is still an artificial method of judgment based on a priori.  This method is a good basic decision method, although it ignores the influence of some potential factors on the decision.

#### Reference

Cools, S.-B., Gershenson, C. and D’Hooghe, B. (2008). ‘Self-organizing traffic lights: A
realistic simulation’. in, pp. 41–50. doi: 10.1007/978-1-84628-982-8_3.
