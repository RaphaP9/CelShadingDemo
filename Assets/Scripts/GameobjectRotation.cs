using UnityEngine;

public class GameobjectRotation : MonoBehaviour
{
    [Header("Settings")]
    [SerializeField] private Vector3 angularVelocity;
    private void Update()
    {
        HandleRotation();
    }

    private void HandleRotation()
    {
        transform.Rotate(angularVelocity * Time.deltaTime, Space.Self);
    }
}