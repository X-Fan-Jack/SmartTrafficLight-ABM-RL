# SmartTrafficLight-ABM-RL

Dissertation for MSc Urban Spatial Science, UCL

word count: 10,000

## Research task

1. Using ABM(agent-based modeling) method simulate the local traffic network.
2. Using RL(Reinforcement learning) train the traffic light agent and get the best property signal pattern to optimize the traffic flow.

## Key point

1. Traffic flow simulation based on ABM (Road network, traffic lights, cars)
2. Reinforcement learning algorithms

## Deadline

Literature Review --- 29th, May.

## Data description

Data source: [Road traffic statistics](https://roadtraffic.dft.gov.uk/downloads)

### Major roads database(MRDB)

Filename: MRDB_2021.shp

Format: shp

CRS: EPSG-27700

Attributes:


| Name          | Type   | Note                     |
| :-------------- | :------- | -------------------------- |
| CP_Numbercol  | double | count point id           |
| RoadNumbercol | string | Road code like A1 or M90 |

A for A-roads which means the main road,
M for Motorways.

### Traffic counts data

Filename: dft_traffic_counts_raw_counts.csv

Format: csv

Description:

This dataset contains the main road statistic data and its each line shows that when and how many cars pass the specific road.

The dataset contains main fields: count_time, countpoint_id, countpoint_longitude, countpoint_latitude, road_name, road_id, cars_type, cars_count...

Furthermore, dft_traffic_counts_aadf_by_direction.csv this dataset means Road level Annual Average Daily Flow
