#ifndef SYSTEM_HPP
#define SYSTEM_HPP

#include "cassie_system_types.h"
#include "mujoco.h"


class System
{
public:
    System();
    System(const System&) = delete;
    System& operator=(const System&) = delete;
    System(System&&) = default;
    System& operator=(System&&) = default;
    ~System();

    void step(const mjModel* m, mjData* d);
    ethercat_data_t ethercat;

private:
    cassie_system_t* system;

};


#endif // SYSTEM_HPP
