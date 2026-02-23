import numpy as np
import pandas as pd

def generate_dataset_8000(total_samples=8000, anomaly_ratio=0.2, random_state=42):
    np.random.seed(random_state)

    normal_count = int(total_samples * (1 - anomaly_ratio))
    anomaly_count = total_samples - normal_count

    # -------------------
    # NORMAL TRAFFIC
    # -------------------
    normal = pd.DataFrame({
        "packet_size": np.maximum(
            np.random.normal(1500, 250, normal_count).astype(int), 64
        ),
        "src_port": np.random.randint(1024, 65535, normal_count),
        "dest_port": np.random.choice([80, 443, 53, 22], normal_count),
        "duration": np.random.uniform(0.05, 6.0, normal_count),
        "protocol_type": np.random.choice([0, 1], normal_count, p=[0.8, 0.2]),
    })

    # -------------------
    # ANOMALOUS TRAFFIC
    # -------------------
    anomaly = pd.DataFrame({
        "packet_size": np.maximum(
            np.random.normal(12000, 3000, anomaly_count).astype(int), 5000
        ),
        "src_port": np.random.randint(1, 1023, anomaly_count),
        "dest_port": np.random.randint(49152, 65535, anomaly_count),
        "duration": np.random.uniform(30, 300, anomaly_count),
        "protocol_type": np.random.choice([2, 3], anomaly_count),
    })

    df = pd.concat([normal, anomaly], ignore_index=True)
    df["true_label"] = [0] * normal_count + [1] * anomaly_count

    return df.sample(frac=1).reset_index(drop=True)

df = generate_dataset_8000()
df.to_csv("CyberSecureAI.csv", index=False)
