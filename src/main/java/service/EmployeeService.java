package com.example.employee.service;

import com.example.employee.model.Employee;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class EmployeeService {

    public List<Employee> getEmployees() {

        return List.of(
                new Employee(1L,"Hari","Cloud"),
                new Employee(2L,"John","DevOps"),
                new Employee(3L,"Raj","Java")
        );
    }
}
